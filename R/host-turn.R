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
# turn at a time; a turn from another tab never does. For the same reason, a
# turn whose first call arrives after a later one from its tab has begun is
# cancelled at once. The scientist can discard what an unfinished turn staged.

host_word_sources <- c("typed", "suggestion", "ask_scientist")

# The scientist's words as the host vouches for them: what they typed, a
# suggestion they clicked, or an answer they gave to a host question, each
# saying which. They replace the workbench's transcript, so the quote checks
# run on them unchanged, and `via` goes into each draft's provenance.
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
    via <- w$via
    if (
      !is.character(via) ||
        length(via) != 1L ||
        !via %in% host_word_sources
    ) {
      abort_suppose(
        "Each of the scientist's words must say whether it was typed, a suggestion or an answer.",
        "source"
      )
    }
    check_text(w$text, "text")
    at <- w$at %||% w$created_at %||% now_utc()
    list(
      role = "user",
      text = w$text,
      status = "complete",
      created_at = as.character(at)[[1]],
      via = via,
      turn = as.character(w$turn %||% NA_character_)[[1]]
    )
  })
}

# The words a turn has been given across its calls: each call's window adds
# what is new, so a quote checked on an earlier call stays in the draft's
# provenance even when a later window no longer holds it.
host_merge_words <- function(old, new) {
  id <- function(w) paste(w$turn, w$via, w$text, sep = "\u001f")
  seen <- vapply(old, id, character(1))
  c(old, Filter(function(w) !id(w) %in% seen, new))
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
  host_read_all(host_paths(store, key)$turns)
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
      # Its process may have stopped part way through publishing; what it
      # wrote was never reviewable (host_draft_status()), and is marked so.
      host_rollback_drafts(store, key, t)
    }
  }
  invisible(NULL)
}

# The typed words a project's first record starts from: this turn's, or else
# the latest the scientist typed.
host_first_words <- function(words, turn) {
  typed <- Filter(function(w) identical(w$via, "typed"), words)
  if (!length(typed)) {
    return(NULL)
  }
  now <- Filter(function(w) identical(w$turn, turn), typed)
  utils::tail(if (length(now)) now else typed, 1)[[1]]$text
}

# Begins the turn `key$turn`, or returns it if it is running. A turn keeps the
# record open in its tab at its first call. In a project with no record, the
# scientist's typed words start one.
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
  # A call that arrives after a later turn from its tab has begun belongs to a
  # reply that has already ended, so it is recorded as cancelled and stages
  # nothing that could replace the later turn's drafts.
  later <- Filter(
    function(t) {
      identical(t$session, key$session) && host_before(key$turn, t$turn)
    },
    host_turns(store, key)
  )
  if (length(later)) {
    host_turn_write(
      store,
      key,
      list(
        version = 1L,
        turn = key$turn,
        session = key$session,
        record = NULL,
        state = "cancelled",
        settled_at = now_utc(),
        note = "A later reply from the same tab had already begun when this one first called Suppose, so it staged nothing."
      )
    )
    abort_suppose(
      "A later reply from this tab has already begun, so this one cannot stage anything.",
      "cancelled"
    )
  }
  host_supersede_turns(store, key)
  id <- host_current_record(store, key)
  if (is.null(id)) {
    text <- host_first_words(words, key$turn)
    if (is.null(text)) {
      abort_suppose(
        "This project has no Suppose record yet. One starts from the scientist's typed words.",
        "no_record"
      )
    }
    id <- host_record_new(store, key, text, author = key$user)
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
    words = list(),
    drafts = list()
  )
  host_turn_write(store, key, turn)
  turn
}

# Staged changes are not sealed, so their text lists come back from JSON as
# lists, and an explicitly cleared one as list() rather than character().
host_restore_changes <- function(changes) {
  text <- function(x) {
    if (is.list(x) && all(vapply(x, is.character, logical(1)))) {
      as.character(unlist(x, use.names = FALSE))
    } else {
      x
    }
  }
  for (name in c("expectations", "assumptions", "unresolved")) {
    if (name %in% names(changes$claim)) {
      changes$claim[name] <- list(text(changes$claim[[name]]))
    }
  }
  if (!is.null(changes$ideas)) {
    changes$ideas <- text(changes$ideas)
  }
  changes
}

# What each form already holds, from the latest current draft of it on the
# record, so a follow-up draft keeps the settings it leaves out, as the
# workbench's open form does.
host_form_state <- function(store, key, record, digest) {
  state <- list()
  for (d in host_drafts(store, key, record = record)) {
    form <- d$form
    if (
      is.null(form) ||
        !identical(d$base_digest, digest) ||
        !is.null(state[[form$form]])
    ) {
      next
    }
    state[[form$form]] <- list(
      values = form$values,
      version = object_id(form$values)
    )
  }
  state
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
    changes = host_restore_changes(turn$changes),
    receipts = turn$receipts %||% list(),
    previous = previous,
    changed = isTRUE(turn$changed),
    form_drafts = turn$form_drafts %||% list(),
    form_state = host_form_state(store, key, turn$record, turn$base_digest)
  )
  s$phase <- "running"
  s$published <- published
  s
}

# A tool's arguments as the tool declares them. Over MCP they arrive as
# parsed JSON, where an array is a list; ellmer converts them the same way
# before it calls a tool.
host_tool_arguments <- function(tool, arguments) {
  types <- tool@arguments@properties
  arguments <- arguments[!vapply(arguments, is.null, logical(1))]
  for (name in intersect(names(arguments), names(types))) {
    value <- arguments[[name]]
    type <- types[[name]]
    if (S7::S7_inherits(type, ellmer::TypeArray) && is.list(value)) {
      scalar <- vapply(
        value,
        function(v) is.atomic(v) && length(v) == 1L,
        logical(1)
      )
      if (all(scalar)) {
        items <- type@items
        value <- if (
          !length(value) && S7::S7_inherits(items, ellmer::TypeBasic)
        ) {
          switch(
            items@type,
            number = numeric(),
            integer = integer(),
            boolean = logical(),
            character()
          )
        } else {
          unlist(value, use.names = FALSE)
        }
      }
    } else if (is.list(value) && length(value) == 1L && is.atomic(value[[1]])) {
      value <- value[[1]]
    }
    arguments[name] <- list(value)
  }
  arguments
}

# Calls one of the assistant's inquiry tools for a host's turn: `key` names
# the tab and turn, `words` are the scientist's words the host supplied, and
# `arguments` are the tool's, by name. Returns the tool's result with the
# record and turn it acted on.
host_call_tool <- function(store, key, words, name, arguments = list()) {
  words <- host_words(words)
  turn <- host_begin_turn(store, key, words)
  words <- host_merge_words(turn$words %||% list(), words)
  s <- host_session(store, key, turn, words)
  tools <- s$tools(turn$turn)
  names(tools) <- vapply(tools, function(t) t@name, character(1))
  if (!name %in% names(tools)) {
    abort_suppose("Suppose has no tool {.val {name}}.", "unknown_tool")
  }
  tool <- tools[[name]]
  value <- do.call(tool, host_tool_arguments(tool, arguments))
  turn$changes <- s$request$changes
  turn$receipts <- s$request$receipts
  turn$changed <- isTRUE(s$request$changed)
  turn$form_drafts <- s$request$form_drafts %||% list()
  turn$words <- words
  host_turn_write(store, key, turn)
  list(value = value, record = turn$record, turn = turn$turn)
}

# Records how a host's turn ended. `done` makes what the turn staged a review;
# `stopped` and `failed` discard it. A turn already settled is left as it is,
# and a turn Suppose never saw is recorded as settled, so a call that arrives
# after the report cannot start it.
host_settle_turn <- function(store, key, outcome) {
  outcome <- rlang::arg_match0(outcome, c("done", "stopped", "failed"))
  check_text(key$turn, "turn")
  turn <- host_turn_read(store, key, key$turn)
  if (is.null(turn)) {
    # A reply that used no Suppose tool still ends the tab's earlier ones, as
    # its first call would have, so none of them can publish after it.
    if (!is.null(key$session)) {
      host_supersede_turns(store, key)
    }
    turn <- list(
      version = 1L,
      turn = key$turn,
      session = key$session,
      record = NULL,
      state = outcome,
      outcome = outcome,
      settled_at = now_utc(),
      note = "The host reported how this reply ended before it called Suppose."
    )
    host_turn_write(store, key, turn)
    return(invisible(turn))
  }
  if (!identical(turn$state, "running")) {
    return(invisible(turn))
  }
  if (!is.null(key$session) && !identical(turn$session, key$session)) {
    abort_suppose("This reply belongs to another tab.", "cancelled")
  }
  turn$outcome <- outcome
  turn$settled_at <- now_utc()
  if (identical(outcome, "done")) {
    finished <- tryCatch(
      {
        s <- host_session(store, key, turn, turn$words %||% list())
        s$finish(turn$turn, "")
        host_publish_drafts(store, key, turn, s)
      },
      suppose_stale = function(e) {
        host_rollback_drafts(store, key, turn)
        structure(
          "The record changed during this reply, so its drafts were not published.",
          class = "host_not_published"
        )
      },
      error = function(e) {
        host_rollback_drafts(store, key, turn)
        structure(
          paste(
            "Suppose could not finish this reply's drafts:",
            cli::ansi_strip(conditionMessage(e))
          ),
          class = c("host_failed", "host_not_published")
        )
      }
    )
    if (inherits(finished, "host_not_published")) {
      turn$note <- unclass(finished)
      turn$state <- if (inherits(finished, "host_failed")) "failed" else "done"
    } else {
      turn$drafts <- finished
      turn$state <- "done"
    }
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

# A draft's status as the settled turns have it. A turn's record is written
# whole when it settles, and that write is the commit: a draft is ready only
# once its turn has settled `done` with the draft among those it published,
# and a draft replaced by one whose turn never got that far is ready again.
# So a process that stops while a turn publishes, where no handler can undo
# anything (host_rollback_drafts()), leaves nothing of that turn in review.
# `published` are the ids settled turns published; `states` each turn's state
# by id. A draft not yet committed is `staged` while its turn runs and
# `failed` once it has ended any other way.
host_draft_status <- function(d, published, states) {
  status <- as.character(d$status %||% "")
  if (
    identical(status, "superseded") && !isTRUE(d$superseded_by %in% published)
  ) {
    status <- "ready"
  }
  if (identical(status, "ready") && !isTRUE(d$id %in% published)) {
    state <- states[[as.character(d$turn %||% "")]] %||% ""
    status <- if (identical(state, "running")) "staged" else "failed"
  }
  status
}

# The conversation's drafts, newest first, each with its status as the settled
# turns have it (host_draft_status()); by default only those awaiting review.
host_drafts <- function(
  store,
  key,
  record = NULL,
  kind = NULL,
  status = "ready"
) {
  turns <- host_turns(store, key)
  published <- unlist(lapply(turns, function(t) {
    if (identical(t$state, "done")) as.character(unlist(t$drafts))
  }))
  states <- stats::setNames(
    lapply(turns, function(t) as.character(t$state %||% "")),
    vapply(turns, function(t) as.character(t$turn %||% ""), character(1))
  )
  drafts <- lapply(host_read_all(host_paths(store, key)$drafts), function(d) {
    d$status <- host_draft_status(d, published, states)
    d
  })
  drafts <- Filter(
    function(d) {
      (is.null(status) || d$status %in% status) &&
        (is.null(record) || identical(d$record, record)) &&
        (is.null(kind) || identical(d$kind, kind))
    },
    drafts
  )
  host_newest_first(drafts, "created_at")
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

# `id` is ready (host_drafts()): on disk it may still say `superseded` by a
# draft whose turn never settled, and the new draft now replaces it instead.
host_draft_supersede <- function(store, key, id, by) {
  d <- host_draft_read(store, key, id)
  if (is.null(d) || !d$status %in% c("ready", "superseded")) {
    return(invisible(d))
  }
  d$status <- "superseded"
  d$superseded_by <- by
  d$settled_at <- now_utc()
  host_write_json(d, host_draft_path(store, key, id))
  invisible(d)
}

# A new draft replaces the ready drafts of its kind on its record that were
# there before its turn began. One another tab published while the turn ran
# stays beside it, for the scientist to choose between.
host_replace_drafts <- function(store, key, turn, kind, id) {
  for (old in host_drafts(store, key, record = turn$record, kind = kind)) {
    if (
      !identical(old$id, id) &&
        host_before(old$created_at %||% "", turn$started_at %||% "")
    ) {
      host_draft_supersede(store, key, old$id, by = id)
    }
  }
}

# Undoes a publication that stopped part way: the turn's drafts leave review
# and the drafts they replaced are ready again, so a turn that did not finish
# publishing publishes nothing. Best effort: a store that cannot be written
# now leaves the turn failed all the same.
host_rollback_drafts <- function(store, key, turn) {
  tryCatch(
    {
      drafts <- host_read_all(host_paths(store, key)$drafts)
      mine <- Filter(function(d) identical(d$turn, turn$turn), drafts)
      ids <- vapply(mine, function(d) as.character(d$id), character(1))
      for (d in mine) {
        if (identical(d$status, "ready")) {
          d$status <- "failed"
          d$settled_at <- now_utc()
          host_write_json(d, host_draft_path(store, key, d$id))
        }
      }
      for (d in drafts) {
        if (
          identical(d$status, "superseded") && isTRUE(d$superseded_by %in% ids)
        ) {
          d$status <- "ready"
          d$superseded_by <- NULL
          d$settled_at <- NULL
          host_write_json(d, host_draft_path(store, key, d$id))
        }
      }
    },
    error = function(e) NULL
  )
  invisible(NULL)
}

# Writes what a finished turn staged as drafts awaiting review.
host_publish_drafts <- function(store, key, turn, s) {
  ids <- character()
  p <- s$published$proposal
  previous <- if (!is.null(turn$previous)) {
    host_draft_read(store, key, turn$previous)
  }
  if (!is.null(p) && !identical(p$id, previous$proposal$id)) {
    id <- host_draft_write(store, key, turn, "interpretation", proposal = p)
    host_replace_drafts(store, key, turn, "interpretation", id)
    ids <- c(ids, id)
  }
  for (form in s$published$forms) {
    id <- host_draft_write(store, key, turn, form$form, form = form)
    host_replace_drafts(store, key, turn, form$form, id)
    ids <- c(ids, id)
  }
  ids
}
