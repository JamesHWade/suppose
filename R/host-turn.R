# Replies driven by a host.
#
# The workbench begins a request when the scientist sends a message, and
# finishes or cancels it when the reply ends (new_proposal_session()). A host
# drives the same machine from its own turns. The first call carrying a new
# turn id begins it with the scientist's words the host supplied, and the
# host's report of how the turn ended finishes it (`done`) or cancels it
# (`stopped`, `failed`). What a turn drafts becomes a review only when its
# turn is done, so a stopped reply leaves nothing to approve.
#
# A turn that never reports, because the host restarted mid-reply, stays
# unfinished. A later turn from the same tab cancels it, since a tab runs one
# turn at a time; a turn from another tab never does. The scientist can
# discard what an unfinished turn staged.

# The scientist's words as the host vouches for them: what they typed, a
# suggestion they clicked, or an answer they gave to a host question. They
# replace the workbench's transcript, so the quote checks run on them
# unchanged, and `via` goes into each draft's provenance.
host_words <- function(words) {
  items <- if (
    is.list(words) && !is.null(names(words)) && "items" %in% names(words)
  ) {
    words$items
  } else {
    words
  }
  if (is.null(items)) {
    return(list())
  }
  if (!is.list(items)) {
    abort_suppose("The scientist's words must be a list of items.", "source")
  }
  lapply(items, function(w) {
    via <- w$via %||% "typed"
    if (
      !is.character(via) ||
        length(via) != 1L ||
        !via %in% c("typed", "suggestion", "ask_scientist")
    ) {
      abort_suppose(
        "The scientist's words come from typing, a suggestion or an answer.",
        "source"
      )
    }
    check_text(w$text, "text")
    list(
      role = "user",
      text = w$text,
      status = "complete",
      via = via,
      turn = w$turn %||% NA_character_
    )
  })
}

host_turn_path <- function(store, key, turn) {
  fs::path(host_paths(store, key)$turns, paste0(host_segment(turn), ".json"))
}

host_turn_read <- function(store, key, turn) {
  host_read_json(host_turn_path(store, key, turn))
}

host_turn_write <- function(store, key, turn) {
  host_write_json(turn, host_turn_path(store, key, turn$turn))
}

host_turns <- function(store, key) {
  dir <- host_paths(store, key)$turns
  if (!fs::dir_exists(dir)) {
    return(list())
  }
  Filter(
    Negate(is.null),
    unname(lapply(fs::dir_ls(dir, glob = "*.json"), host_read_json))
  )
}

# Whether turn id `a` started before `b`, compared byte by byte whatever the
# locale.
host_before <- function(a, b) {
  !identical(a, b) && identical(sort(c(a, b), method = "radix")[[1]], a)
}

# A tab runs one turn at a time, so a later turn from it means any earlier one
# still unfinished has ended without reporting.
host_supersede_turns <- function(store, key) {
  for (t in host_turns(store, key)) {
    if (
      identical(t$state, "running") &&
        identical(t$session, key$session) &&
        host_before(t$turn, key$turn)
    ) {
      t$state <- "cancelled"
      t$settled_at <- now_utc()
      t$note <- "A later reply from the same tab began before this one reported how it ended, so nothing it staged reached review."
      host_turn_write(store, key, t)
    }
  }
  invisible(NULL)
}

# Begins the turn `key$turn`, or returns it if it is running. A turn keeps the
# record open in its tab at its first call. In a project with no record, the
# scientist's first typed words start one.
host_begin_turn <- function(store, key, words) {
  check_text(key$session, "session")
  check_text(key$turn, "turn")
  turn <- host_turn_read(store, key, key$turn)
  if (!is.null(turn)) {
    if (!identical(turn$session, key$session)) {
      abort_suppose("This reply belongs to another tab.", "cancelled")
    }
    if (!identical(turn$state, "running")) {
      abort_suppose(
        "This reply has ended, so what it staged can no longer change.",
        "cancelled"
      )
    }
    return(turn)
  }
  host_supersede_turns(store, key)
  id <- host_current_record(store, key)
  if (is.null(id)) {
    typed <- Filter(function(w) identical(w$via, "typed"), words)
    if (!length(typed)) {
      abort_suppose(
        "This project has no Suppose record yet. One starts from the scientist's first typed words.",
        "no_record"
      )
    }
    id <- host_record_new(store, key, typed[[1]]$text, author = key$user)
  }
  if (is.null(host_conversation(store, key)$open[[key$session]])) {
    host_open_record(store, key, id)
  }
  x <- host_record_read(store, key, id)
  digest <- proposal_basis_id(x)
  # A draft awaiting review on this revision carries over, as the workbench's
  # pending suggestion does, and the turn's own draft replaces it.
  previous <- host_previous_draft(store, key, id, digest)
  turn <- list(
    version = 1L,
    turn = key$turn,
    session = key$session,
    record = id,
    base_digest = digest,
    state = "running",
    started_at = now_utc(),
    settled_at = NULL,
    note = NULL,
    model = key$model,
    previous = previous$id,
    changes = previous$proposal$changes %||% proposal_changes(),
    receipts = previous$proposal$context$tool_results %||% list(),
    changed = FALSE,
    form_drafts = list(),
    words = words,
    drafts = list()
  )
  host_turn_write(store, key, turn)
  turn
}

# A proposal session holding the turn's staged work, against the turn's
# record as it was when the turn began.
host_session <- function(store, key, turn, words) {
  x <- host_record_read(store, key, turn$record)
  if (!identical(proposal_basis_id(x), turn$base_digest)) {
    abort_suppose(
      "The record changed during this reply. Ask again against the new revision.",
      "stale"
    )
  }
  published <- new.env(parent = emptyenv())
  published$forms <- list()
  s <- new_proposal_session(
    function() {
      meta <- host_record_meta(store, key, turn$record)
      if (identical(meta$digest, turn$base_digest)) {
        x
      } else {
        host_record_read(store, key, turn$record)
      }
    },
    publish = function(p) published$proposal <- p,
    model = turn$model %||% "unknown",
    provider = "host",
    general = TRUE,
    publish_form = function(draft) published$forms[[draft$form]] <- draft
  )
  previous <- if (!is.null(turn$previous)) {
    host_draft_read(store, key, turn$previous)$proposal
  }
  s$messages <- words
  s$request <- list(
    id = turn$turn,
    base = x,
    changes = turn$changes,
    receipts = turn$receipts %||% list(),
    previous = previous,
    changed = isTRUE(turn$changed),
    form_drafts = turn$form_drafts %||% list(),
    form_state = list()
  )
  s$phase <- "running"
  s$published <- published
  s
}

# Calls one of the assistant's inquiry tools for a host's turn: `key` names
# the tab and turn, `words` are the scientist's words the host supplied, and
# `arguments` are the tool's, by name. Returns the tool's result with the
# record and turn it acted on.
host_call_tool <- function(store, key, words, name, arguments = list()) {
  words <- host_words(words)
  turn <- host_begin_turn(store, key, words)
  s <- host_session(store, key, turn, words)
  tools <- s$tools(turn$turn)
  names(tools) <- vapply(tools, function(t) t@name, character(1))
  if (!name %in% names(tools)) {
    abort_suppose("Suppose has no tool {.val {name}}.", "unknown_tool")
  }
  value <- do.call(tools[[name]], arguments)
  turn$changes <- s$request$changes
  turn$receipts <- s$request$receipts
  turn$changed <- isTRUE(s$request$changed)
  turn$form_drafts <- s$request$form_drafts %||% list()
  turn$words <- words
  host_turn_write(store, key, turn)
  list(value = value, record = turn$record, turn = turn$turn)
}

# Records how a host's turn ended. `done` makes what the turn staged a review;
# `stopped` and `failed` discard it. A turn already settled, or one that never
# called a tool, is left as it is.
host_settle_turn <- function(store, key, outcome) {
  outcome <- rlang::arg_match0(outcome, c("done", "stopped", "failed"))
  check_text(key$turn, "turn")
  turn <- host_turn_read(store, key, key$turn)
  if (is.null(turn) || !identical(turn$state, "running")) {
    return(invisible(turn))
  }
  if (!is.null(key$session) && !identical(turn$session, key$session)) {
    abort_suppose("This reply belongs to another tab.", "cancelled")
  }
  turn$outcome <- outcome
  turn$settled_at <- now_utc()
  if (identical(outcome, "done")) {
    s <- tryCatch(
      host_session(store, key, turn, turn$words %||% list()),
      suppose_stale = function(e) NULL
    )
    if (is.null(s)) {
      turn$note <- "The record changed during this reply, so its drafts were not published."
    } else {
      s$finish(turn$turn, "")
      turn$drafts <- host_publish_drafts(store, key, turn, s)
    }
    turn$state <- "done"
  } else {
    turn$state <- outcome
    turn$note <- sprintf(
      "The reply %s, so nothing it staged reached review.",
      if (identical(outcome, "stopped")) "was stopped" else "failed"
    )
  }
  host_turn_write(store, key, turn)
  invisible(turn)
}

# The scientist discards an unfinished turn's staged work.
host_discard_turn <- function(store, key, turn) {
  t <- host_turn_read(store, key, turn)
  if (is.null(t) || !identical(t$state, "running")) {
    return(invisible(t))
  }
  t$state <- "discarded"
  t$settled_at <- now_utc()
  t$note <- "Discarded by the scientist before the reply reported how it ended."
  host_turn_write(store, key, t)
  invisible(t)
}

# --- Drafts -----------------------------------------------------------------

host_draft_path <- function(store, key, id) {
  fs::path(host_paths(store, key)$drafts, paste0(host_segment(id), ".json"))
}

host_draft_read <- function(store, key, id) {
  host_read_json(host_draft_path(store, key, id))
}

# The conversation's drafts, newest first; by default only those awaiting
# review.
host_drafts <- function(
  store,
  key,
  record = NULL,
  kind = NULL,
  status = "ready"
) {
  dir <- host_paths(store, key)$drafts
  if (!fs::dir_exists(dir)) {
    return(list())
  }
  drafts <- Filter(
    Negate(is.null),
    unname(lapply(fs::dir_ls(dir, glob = "*.json"), host_read_json))
  )
  drafts <- Filter(
    function(d) {
      (is.null(status) || d$status %in% status) &&
        (is.null(record) || identical(d$record, record)) &&
        (is.null(kind) || identical(d$kind, kind))
    },
    drafts
  )
  if (!length(drafts)) {
    return(list())
  }
  at <- vapply(drafts, function(d) d$created_at %||% "", character(1))
  drafts[order(at, decreasing = TRUE)]
}

host_previous_draft <- function(store, key, record, digest) {
  for (d in host_drafts(store, key, record = record, kind = "interpretation")) {
    if (identical(d$base_digest, digest)) {
      return(d)
    }
  }
  NULL
}

host_draft_write <- function(
  store,
  key,
  turn,
  kind,
  proposal = NULL,
  form = NULL
) {
  payload <- proposal %||% form
  id <- paste0("d-", substr(payload$id, 1L, 12L))
  host_write_json(
    list(
      version = 1L,
      id = id,
      kind = kind,
      record = turn$record,
      turn = turn$turn,
      session = turn$session,
      base_digest = turn$base_digest,
      status = "ready",
      created_at = now_utc(),
      proposal = proposal,
      form = form
    ),
    host_draft_path(store, key, id)
  )
  id
}

host_draft_supersede <- function(store, key, id, by) {
  d <- host_draft_read(store, key, id)
  if (is.null(d) || !identical(d$status, "ready")) {
    return(invisible(d))
  }
  d$status <- "superseded"
  d$superseded_by <- by
  d$settled_at <- now_utc()
  host_write_json(d, host_draft_path(store, key, id))
  invisible(d)
}

# Writes what a finished turn staged as drafts awaiting review. A draft
# replaces the earlier one of the same kind on the same record.
host_publish_drafts <- function(store, key, turn, s) {
  ids <- character()
  p <- s$published$proposal
  previous <- if (!is.null(turn$previous)) {
    host_draft_read(store, key, turn$previous)
  }
  if (!is.null(p) && !identical(p$id, previous$proposal$id)) {
    id <- host_draft_write(store, key, turn, "interpretation", proposal = p)
    for (old in host_drafts(
      store,
      key,
      record = turn$record,
      kind = "interpretation"
    )) {
      if (!identical(old$id, id)) {
        host_draft_supersede(store, key, old$id, by = id)
      }
    }
    ids <- c(ids, id)
  }
  for (form in s$published$forms) {
    id <- host_draft_write(store, key, turn, form$form, form = form)
    for (old in host_drafts(
      store,
      key,
      record = turn$record,
      kind = form$form
    )) {
      if (!identical(old$id, id)) {
        host_draft_supersede(store, key, old$id, by = id)
      }
    }
    ids <- c(ids, id)
  }
  ids
}
