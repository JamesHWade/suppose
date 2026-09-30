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
#   records/<id>/record.json     a record bundle, as write_record() writes it
#   records/<id>/meta.json       its title, digest and state revision
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
    host_check_id(get(arg), arg)
  }
  host_check_id(session, "session", optional = TRUE)
  host_check_id(turn, "turn", optional = TRUE)
  host_check_id(model, "model", optional = TRUE)
  list(
    user = user,
    project = project,
    conversation = conversation,
    session = session,
    turn = turn,
    model = model
  )
}

# A host's ids are short, so none can crowd the state document past its size.
# They are measured as the state document writes them: in JSON, where a quote
# or a backslash takes two characters. Control characters, which take up to
# six there, have no place in an id.
host_id_limit <- 200L

host_check_id <- function(x, arg, optional = FALSE) {
  check_text(x, arg, optional = optional)
  if (is.null(x)) {
    return(invisible(x))
  }
  if (grepl("[[:cntrl:]]", x)) {
    abort_suppose(
      "{.arg {arg}} must not contain control characters.",
      arg = arg
    )
  }
  if (sum(host_json_cost(strsplit(x, "")[[1]])) > host_id_limit) {
    abort_suppose(
      "{.arg {arg}} must be at most {host_id_limit} characters, a quote, backslash or emoji counting as two.",
      arg = arg
    )
  }
  invisible(x)
}

# A host's identifier as one path segment. A short, plain name is used as it
# is; anything else becomes `+`, a readable slug and a digest. A plain name
# cannot start with `+`, so two ids never share a folder.
host_segment <- function(x) {
  if (grepl("^[A-Za-z0-9_-][A-Za-z0-9._-]{0,79}$", x)) {
    return(x)
  }
  slug <- substr(gsub("[^A-Za-z0-9._-]+", "-", x), 1L, 40L)
  slug <- gsub("^[.-]+", "", slug)
  paste0(
    "+",
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

# The files in a directory of the store, read, in no particular order.
host_read_all <- function(dir, glob = "*.json") {
  if (!fs::dir_exists(dir)) {
    return(list())
  }
  Filter(
    Negate(is.null),
    unname(lapply(fs::dir_ls(dir, glob = glob), host_read_json))
  )
}

# Newest first by an ISO timestamp field, whatever the locale.
# A UTC timestamp as seconds, for ordering: as text, a stamp with fractions
# of a second sorts before the same second without them, though it is later.
# NA for one that is not a timestamp.
host_time <- function(x) {
  as.numeric(as.POSIXct(
    as.character(x),
    format = "%Y-%m-%dT%H:%M:%OSZ",
    tz = "UTC"
  ))
}

host_newest_first <- function(items, field) {
  if (!length(items)) {
    return(list())
  }
  at <- vapply(
    items,
    function(i) as.character(i[[field]] %||% ""),
    character(1)
  )
  items[order(host_time(at), at, decreasing = TRUE, method = "radix")]
}

# --- Records ----------------------------------------------------------------

# Each record has a directory of its own, so no id can name another's file.
host_record_dir <- function(store, key, id) {
  fs::path(host_paths(store, key)$records, host_segment(id))
}

host_record_meta <- function(store, key, id) {
  host_read_json(fs::path(host_record_dir(store, key, id), "meta.json"))
}

# The project's records, most recently changed first.
host_records <- function(store, key) {
  dir <- host_paths(store, key)$records
  if (!fs::dir_exists(dir)) {
    return(list())
  }
  metas <- lapply(
    fs::path(fs::dir_ls(dir, type = "directory"), "meta.json"),
    host_read_json
  )
  host_newest_first(Filter(Negate(is.null), unname(metas)), "updated_at")
}

host_record_read <- function(store, key, id) {
  path <- fs::path(host_record_dir(store, key, id), "record.json")
  if (!fs::file_exists(path)) {
    abort_suppose(
      "There is no record {.val {id}} in this project.",
      "no_record",
      record = id
    )
  }
  read_record(path)
}

# Writes a record and its meta. `digest` is the record's proposal basis, which
# drafts are made against and which a recorded analysis leaves alone. The
# state revision rises whenever anything in the record changes, analyses
# included, which its revision count does not do for attached data, fits or
# frozen tests.
host_record_write <- function(store, key, id, x, title = NULL) {
  host_check_id(id, "id")
  validate_record(x)
  dir <- host_record_dir(store, key, id)
  fs::dir_create(dir)
  old <- host_record_meta(store, key, id)
  content <- object_id(x)
  write_record(x, fs::path(dir, "record.json"), overwrite = TRUE)
  changed <- !identical(old$content_digest, content)
  meta <- list(
    id = id,
    title = title %||% old$title %||% x$record_id,
    digest = proposal_basis_id(x),
    content_digest = content,
    state_revision = (old$state_revision %||% 0L) + as.integer(changed),
    revisions = length(x$revisions),
    revised_at = host_revised_at(old, length(x$revisions)),
    review = host_review(x),
    updated_at = if (changed) now_utc() else old$updated_at %||% now_utc()
  )
  host_write_json(meta, fs::path(dir, "meta.json"))
  invisible(meta)
}

# When each revision was first written here, since a revision carries no
# stamp of its own: a revision that adds nothing stamped (one that clears a
# fit, say) is dated by it (host_last_decision()). Revisions a record already
# had when this store first saw it, or before it kept these times, are left
# undated ("") rather than dated by a later write.
host_revised_at <- function(old, n) {
  known <- as.character(unlist(old$revised_at %||% list()))
  seen <- if (is.null(old)) n else as.integer(old$revisions %||% 0L)
  known <- c(known, rep("", max(0L, seen - length(known))))
  if (n <= length(known)) {
    return(known[seq_len(n)])
  }
  c(known, rep(now_utc(), n - length(known)))
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
