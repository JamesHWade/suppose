# A store for hosts that own the conversation.
#
# In the workbench, the conversation, the drafts and the record live in one
# Shiny session. A host such as Crucible owns the conversation instead: it
# calls Suppose's tools one at a time, naming the person, project,
# conversation, browser tab and turn, and supplying the scientist's own
# words. So what a turn stages lives on disk, per person and project, and
# every call rebuilds what it needs from there. Drafting needs no pane
# session, and a restarted process loses nothing but the call in flight.
#
# <dir>/users/<user>/<project>/
#   records/<id>.json            a record bundle, as write_record() writes it
#   records/<id>.meta.json       its title, digest and state revision
#   conversations/<conversation>/
#     state.json                 the open record per tab and the last opened
#     turns/<turn>.json          what a turn staged, and how it ended
#     drafts/<id>.json           drafts ready for review
#
# Writes replace whole files through a rename. One process serves a store;
# locking and compare-and-swap on record digests come with shared records.

host_store <- function(dir) {
  check_text(dir, "dir")
  structure(list(dir = fs::path_abs(dir)), class = "suppose_host_store")
}

# The host's identifiers for one call. `session` names the browser tab and
# `turn` the reply; turn ids must sort in the order turns start (ULIDs do).
# `model` is the host's model, kept in each draft's provenance.
host_key <- function(
  user,
  project,
  conversation,
  session = NULL,
  turn = NULL,
  model = NULL
) {
  for (arg in c("user", "project", "conversation")) {
    check_text(get(arg), arg)
  }
  check_text(session, "session", optional = TRUE)
  check_text(turn, "turn", optional = TRUE)
  check_text(model, "model", optional = TRUE)
  list(
    user = user,
    project = project,
    conversation = conversation,
    session = session,
    turn = turn,
    model = model
  )
}

# A host's identifier as one path segment. Anything that is not already a
# short, plain name gets a digest suffix, so two ids never share a folder.
host_segment <- function(x) {
  if (grepl("^[A-Za-z0-9_-][A-Za-z0-9._-]{0,79}$", x)) {
    return(x)
  }
  slug <- substr(gsub("[^A-Za-z0-9._-]+", "-", x), 1L, 40L)
  slug <- gsub("^[.-]+", "", slug)
  paste0(
    if (nzchar(slug)) paste0(slug, "-") else "",
    substr(digest::digest(x, algo = "sha256", serialize = FALSE), 1L, 12L)
  )
}

host_paths <- function(store, key) {
  project <- fs::path(
    store$dir,
    "users",
    host_segment(key$user),
    host_segment(key$project)
  )
  conversation <- fs::path(
    project,
    "conversations",
    host_segment(key$conversation)
  )
  list(
    project = project,
    records = fs::path(project, "records"),
    conversation = conversation,
    state = fs::path(conversation, "state.json"),
    turns = fs::path(conversation, "turns"),
    drafts = fs::path(conversation, "drafts")
  )
}

host_write_json <- function(x, path) {
  fs::dir_create(fs::path_dir(path))
  tmp <- tempfile(pattern = ".suppose-", tmpdir = fs::path_dir(path))
  withr::defer(unlink(tmp))
  writeLines(json_data(x, pretty = TRUE), tmp, useBytes = TRUE)
  fs::file_move(tmp, path)
  invisible(path)
}

host_read_json <- function(path) {
  if (!fs::file_exists(path)) {
    return(NULL)
  }
  x <- tryCatch(
    jsonlite::fromJSON(
      path,
      simplifyVector = TRUE,
      simplifyDataFrame = FALSE,
      simplifyMatrix = FALSE
    ),
    error = function(e) {
      abort_suppose(
        "Cannot read {.path {path}} in the inquiry store.",
        "io",
        parent = e,
        path = path
      )
    }
  )
  restore_record_types(x)
}

# --- Records ----------------------------------------------------------------

host_record_meta <- function(store, key, id) {
  host_read_json(fs::path(
    host_paths(store, key)$records,
    paste0(
      host_segment(id),
      ".meta.json"
    )
  ))
}

# The project's records, most recently changed first.
host_records <- function(store, key) {
  dir <- host_paths(store, key)$records
  if (!fs::dir_exists(dir)) {
    return(list())
  }
  metas <- lapply(
    fs::dir_ls(dir, glob = "*.meta.json"),
    host_read_json
  )
  metas <- Filter(Negate(is.null), unname(metas))
  if (!length(metas)) {
    return(list())
  }
  at <- vapply(metas, function(m) m$updated_at %||% "", character(1))
  metas[order(at, decreasing = TRUE)]
}

host_record_read <- function(store, key, id) {
  path <- fs::path(
    host_paths(store, key)$records,
    paste0(host_segment(id), ".json")
  )
  if (!fs::file_exists(path)) {
    abort_suppose(
      "There is no record {.val {id}} in this project.",
      "no_record",
      record = id
    )
  }
  read_record(path)
}

# Writes a record and its meta. The state revision rises whenever the record's
# content changes, which its revision count does not do for attached data,
# fits or frozen tests.
host_record_write <- function(store, key, id, x, title = NULL) {
  validate_record(x)
  dir <- host_paths(store, key)$records
  fs::dir_create(dir)
  old <- host_record_meta(store, key, id)
  digest <- proposal_basis_id(x)
  write_record(
    x,
    fs::path(dir, paste0(host_segment(id), ".json")),
    overwrite = TRUE
  )
  changed <- !identical(old$digest, digest)
  meta <- list(
    id = id,
    title = title %||% old$title %||% x$record_id,
    digest = digest,
    state_revision = (old$state_revision %||% 0L) + as.integer(changed),
    revisions = length(x$revisions),
    review = host_review(x),
    updated_at = if (changed) now_utc() else old$updated_at %||% now_utc()
  )
  host_write_json(meta, fs::path(dir, paste0(host_segment(id), ".meta.json")))
  invisible(meta)
}

# A project's first record, from the scientist's own words, as the workbench
# starts one on the first message.
host_record_new <- function(store, key, text, author, title = "My inquiry") {
  check_text(text, "text")
  check_text(author, "author")
  x <- elicitation_record(claim(text, author), title)
  id <- paste0(
    "r-",
    substr(
      object_id(list(key$user, key$project, now_utc(), text)),
      1L,
      12L
    )
  )
  host_record_write(store, key, id, x, title = title)
  id
}

host_review <- function(x) {
  e <- utils::tail(x$revisions, 1)[[1]]
  if (is.null(e$acceptance)) {
    "unreviewed"
  } else {
    e$acceptance$kind %||% "numerical candidate"
  }
}

# --- The conversation -------------------------------------------------------

host_conversation <- function(store, key) {
  host_read_json(host_paths(store, key)$state) %||%
    list(version = 1L, open = list(), last_open = NULL, revision = 0L)
}

host_conversation_write <- function(store, key, state) {
  host_write_json(state, host_paths(store, key)$state)
}

# Makes `id` the tab's open record, and the one a new tab opens.
host_open_record <- function(store, key, id) {
  check_text(key$session, "session")
  if (is.null(host_record_meta(store, key, id))) {
    abort_suppose(
      "There is no record {.val {id}} in this project.",
      "no_record",
      record = id
    )
  }
  state <- host_conversation(store, key)
  state$open[[key$session]] <- id
  state$last_open <- id
  host_conversation_write(store, key, state)
  invisible(id)
}

# The record a call from this tab acts on: the tab's open record, else the
# one the conversation last opened in any tab, else the project's latest.
host_current_record <- function(store, key) {
  state <- host_conversation(store, key)
  if (!is.null(key$session) && !is.null(state$open[[key$session]])) {
    return(state$open[[key$session]])
  }
  if (!is.null(state$last_open)) {
    return(state$last_open)
  }
  records <- host_records(store, key)
  if (length(records)) records[[1]]$id else NULL
}
