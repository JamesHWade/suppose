# The state a host shows its model (`suppose/state@1`).
#
# The workbench writes a summary of the record into its own system prompt
# (inquiry_context_summary()), unbounded as a whole: 7,996 characters for
# the regression worked example, 1,428 of them method guidance. A host sends
# an app's state with each turn instead and cuts it at a size of its own
# (Crucible cuts at 8,000 characters of indented JSON). So this document
# carries ids and short text within 6,000 characters in that form, caps
# every list with a count of what it left out, and gives no instructions:
# the method guidance belongs in the host's skill. host_read_inquiry() gives
# the rest, one section and page at a time.

host_state_budget <- 6000L

host_state_approval <- "Only the scientist's buttons in the Suppose pane apply, correct, accept, retain, attach, fit, freeze or assess; tools draft for review and change no record."

host_state_limitations <- c(
  "Prior models: a difference of two jointly normal population means at two numeric conditions, with known batch SDs.",
  "Updates: analytic normal updates from designated independent measurements with known positive SDs.",
  "Regression: unknown-noise normal regression with one or two numeric predictors, fitted by the scientist in the pane.",
  "Prospective and regression tests are frozen and assessed in the pane; an assessment does not establish truth or causality.",
  "Sensitivity checks are exploratory and never change an assessment.",
  "Model worlds are external simulation snapshots, not evidence."
)

# `x` as one string of at most `n` characters as the document writes it, in
# JSON (host_json_cost()), so quotes and control characters in a field cannot
# carry the document past its budget.
host_cut <- function(x, n) {
  if (is.null(x) || !length(x)) {
    return(NULL)
  }
  x <- paste(as.character(unlist(x)), collapse = "; ")
  if (nchar(x) * 6L <= n) {
    return(x)
  }
  chars <- strsplit(x, "")[[1]]
  cost <- cumsum(host_json_cost(chars))
  if (cost[[length(cost)]] <= n) {
    return(x)
  }
  paste0(
    paste(chars[seq_len(findInterval(n - 1L, cost))], collapse = ""),
    "\u2026"
  )
}

# What each character costs once a string is written as JSON: quotes,
# backslashes and the common control characters take two, other control
# characters six (\\u00XX).
host_json_cost <- function(chars) {
  code <- vapply(chars, utf8ToInt, integer(1), USE.NAMES = FALSE)
  cost <- rep(1L, length(chars))
  cost[which(code < 32L)] <- 6L
  cost[chars %in% c("\"", "\\", "\n", "\r", "\t", "\b", "\f")] <- 2L
  cost
}

# Cuts `x` into pieces that each take at most `limit` characters once written
# as a JSON string, so a part of an item is no bigger on the wire than its
# page allows however many quotes it holds.
host_json_chunks <- function(x, limit) {
  chars <- strsplit(x, "")[[1]]
  if (!length(chars)) {
    return("")
  }
  total <- cumsum(host_json_cost(chars))
  out <- character()
  start <- 1L
  offset <- 0
  while (start <= length(chars)) {
    end <- max(start, findInterval(offset + limit, total))
    out <- c(out, paste(chars[start:end], collapse = ""))
    offset <- total[[end]]
    start <- end + 1L
  }
  out
}

host_last_id <- function(entries) {
  if (length(entries)) entries[[length(entries)]]$id else NULL
}

host_json_size <- function(x) {
  nchar(jsonlite::toJSON(
    plain(x),
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA,
    pretty = TRUE
  ))
}

# The record a call reads: its turn's, once the turn has begun, else the
# tab's open record.
host_turn_record <- function(store, key) {
  if (!is.null(key$turn)) {
    turn <- host_turn_read(store, key, key$turn)
    if (!is.null(turn) && identical(turn$state, "running")) {
      return(turn$record)
    }
  }
  host_current_record(store, key)
}

# The conversation's drafts on any record, awaiting review, and what running
# turns have staged, which is not ready until their turn is done. Those on
# `open` first, then the newest.
host_pending <- function(store, key, open = NULL) {
  digests <- list()
  digest_of <- function(record) {
    if (is.null(digests[[record]])) {
      digests[[record]] <<- host_record_meta(store, key, record)$digest %||% ""
    }
    digests[[record]]
  }
  items <- lapply(host_drafts(store, key), function(d) {
    list(
      draft = d$id,
      record = d$record,
      kind = d$kind,
      turn = d$turn,
      base_digest = d$base_digest,
      current = identical(d$base_digest, digest_of(d$record)),
      ready = TRUE,
      at = d$created_at
    )
  })
  for (t in host_turns(store, key)) {
    if (!identical(t$state, "running")) {
      next
    }
    kinds <- c(if (isTRUE(t$changed)) "interpretation", names(t$form_drafts))
    for (kind in kinds) {
      items[[length(items) + 1L]] <- list(
        draft = NULL,
        record = t$record,
        kind = kind,
        turn = t$turn,
        base_digest = t$base_digest,
        current = identical(t$base_digest, digest_of(t$record)),
        ready = FALSE,
        at = t$started_at
      )
    }
  }
  if (!length(items)) {
    return(list())
  }
  on_open <- vapply(items, function(i) identical(i$record, open), logical(1))
  at <- vapply(items, function(i) i$at %||% "", character(1))
  items[order(!on_open, at, decreasing = c(FALSE, TRUE), method = "radix")]
}

host_open_tests <- function(x) {
  replaced <- unlist(lapply(
    c(x$commitments, x$regression_commitments),
    function(c) c$replaces
  ))
  open <- function(commitments, assessments, kind) {
    lapply(commitments, function(c) {
      if (c$id %in% replaced) {
        return(NULL)
      }
      done <- Filter(function(a) identical(a$commitment_id, c$id), assessments)
      last <- if (length(done)) utils::tail(done, 1)[[1]]$status
      if (!is.null(last) && !identical(last, "awaiting_outcomes")) {
        return(NULL)
      }
      list(id = c$id, kind = kind, deadline = c$horizon %||% NA_character_)
    })
  }
  tests <- Filter(
    Negate(is.null),
    c(
      open(x$commitments, x$assessments, "prospective"),
      open(x$regression_commitments, x$regression_assessments, "regression")
    )
  )
  if (!length(tests)) {
    return(list())
  }
  deadline <- vapply(tests, function(t) as.character(t$deadline), character(1))
  tests[order(deadline, na.last = TRUE, method = "radix")]
}

# The latest decision recorded in the record, by its timestamp.
host_last_decision <- function(x, state_revision) {
  found <- list()
  add <- function(what, entry, outcome = NULL, at = entry$created_at) {
    if (is.null(entry) || is.null(at)) {
      return(invisible())
    }
    found[[length(found) + 1L]] <<- list(
      what = what,
      outcome = outcome,
      at = at,
      by = entry$author %||% entry$reviewer %||% NULL
    )
  }
  for (i in seq_along(x$revisions)) {
    e <- x$revisions[[i]]
    if (!is.null(e$assistance)) {
      add(
        sprintf("applied revision %d", i),
        list(author = e$assistance$applied_by),
        at = e$assistance$applied_at
      )
    } else if (i > 1L) {
      # A revision made by hand (a claim edit, a retained judgment, a fitted
      # candidate) has no stamp of its own; what it added has one.
      prev <- x$revisions[[i - 1L]]
      if (!identical(e$claim$id, prev$claim$id)) {
        add(sprintf("revised the claim in revision %d", i), e$claim)
      }
      seen <- vapply(
        prev$judgments %||% list(),
        function(j) as.character(j$id %||% ""),
        character(1)
      )
      for (j in e$judgments %||% list()) {
        if (!as.character(j$id %||% "") %in% seen) {
          add(sprintf("retained a judgment in revision %d", i), j)
        }
      }
      if (
        !is.null(e$candidate) && !identical(e$candidate$id, prev$candidate$id)
      ) {
        add(sprintf("fitted a candidate in revision %d", i), e$candidate)
      }
    }
    if (!is.null(e$acceptance)) {
      add(
        sprintf("reviewed revision %d", i),
        e$acceptance,
        outcome = e$acceptance$kind %||% "numerical candidate"
      )
    }
  }
  kinds <- c(
    observations = "attached measurements",
    predictors = "attached predictors",
    updates = "retained an update",
    commitments = "froze a prospective test",
    sensitivities = "retained a sensitivity check",
    model_extensions = "retained a model extension",
    regressions = "retained a regression",
    research_designs = "retained a research design",
    regression_commitments = "froze a regression test",
    regression_test_data = "attached regression test data",
    regression_sensitivities = "retained a regression sensitivity check",
    model_worlds = "added a model world",
    model_implications = "retained a model implication",
    model_references = "related a claim to a model"
  )
  for (name in names(kinds)) {
    for (entry in x[[name]]) {
      # A model world is stamped in its provenance, not on itself.
      add(
        kinds[[name]],
        entry,
        outcome = entry$choice %||% NULL,
        at = entry$created_at %||% entry$provenance$created_at
      )
    }
  }
  # Assessments are stamped when they were assessed, not created.
  for (entry in c(x$assessments, x$regression_assessments)) {
    add(
      "assessed a test",
      entry,
      outcome = entry$status,
      at = entry$assessed_at %||% entry$created_at
    )
  }
  if (!length(found)) {
    return(NULL)
  }
  at <- vapply(found, function(f) as.character(f$at), character(1))
  last <- found[[order(at, decreasing = TRUE, method = "radix")[[1]]]]
  # `[<-` with a list keeps a field that is NULL, so the document's keys do not
  # change with what a record happens to hold.
  last["outcome"] <- list(host_cut(last$outcome, 80L))
  last["by"] <- list(host_cut(last$by, 80L))
  last["at"] <- list(host_cut(last$at, 40L))
  c(last, list(state_revision = state_revision))
}

# The pane records the form it has open, and whether it has unsaved edits, so
# the model does not draft over them.
host_set_editing <- function(store, key, form = NULL, unsaved = FALSE) {
  check_text(key$session, "session")
  check_text(form, "form", optional = TRUE)
  state <- host_conversation(store, key)
  state$editing[[key$session]] <- if (!is.null(form)) {
    list(form = form, unsaved = isTRUE(unsaved))
  }
  host_conversation_write(store, key, state)
  invisible(form)
}

# The document, for the tab `key$session`. `instance` is the pane's own id;
# `quotes` says whether the host supplies the scientist's words.
host_state <- function(
  store,
  key,
  instance = NULL,
  quotes = "host-verified"
) {
  check_text(key$session, "session")
  host_check_id(instance, "instance", optional = TRUE)
  quotes <- rlang::arg_match0(quotes, c("host-verified", "unverified"))
  editing <- host_conversation(store, key)$editing[[key$session]]
  if (!is.null(editing)) {
    editing <- list(
      form = host_cut(editing$form, 80L),
      unsaved = isTRUE(editing$unsaved)
    )
  }
  id <- host_current_record(store, key)
  records <- host_records(store, key)
  pending <- host_pending(store, key, open = id)
  doc <- list(
    schema = "suppose/state@1",
    instance = instance,
    revision = NULL,
    record = NULL,
    records = list(),
    records_more = 0L,
    claim = NULL,
    review = NULL,
    pending = list(),
    pending_more = 0L,
    pending_counts = list(
      ready = sum(vapply(
        pending,
        function(p) isTRUE(p$ready) && isTRUE(p$current),
        logical(1)
      )),
      stale = sum(vapply(
        pending,
        function(p) isTRUE(p$ready) && !isTRUE(p$current),
        logical(1)
      )),
      drafting = sum(vapply(pending, function(p) !isTRUE(p$ready), logical(1)))
    ),
    editing = editing,
    retained = NULL,
    latest = NULL,
    last_decision = NULL,
    limitations = host_state_limitations,
    quotes = quotes,
    approval = host_state_approval
  )
  x <- NULL
  if (!is.null(id)) {
    x <- host_record_read(store, key, id)
    meta <- host_record_meta(store, key, id)
    e <- utils::tail(x$revisions, 1)[[1]]
    tests <- host_open_tests(x)
    doc$record <- list(
      id = id,
      title = host_cut(meta$title, 120L),
      revision = length(x$revisions),
      digest = meta$digest,
      state_revision = meta$state_revision
    )
    doc$review <- host_review(x)
    doc$retained <- list(
      observations = length(x$observations),
      updates = length(x$updates),
      tests_frozen = length(x$commitments) + length(x$regression_commitments),
      tests_assessed = length(unique(vapply(
        c(x$assessments, x$regression_assessments),
        function(a) as.character(a$commitment_id),
        character(1)
      ))),
      regressions = length(x$regressions),
      designs = length(x$research_designs),
      sensitivity_checks = length(x$sensitivities) +
        length(x$regression_sensitivities),
      model_worlds = length(x$model_worlds)
    )
    doc$last_decision <- host_last_decision(x, meta$state_revision)
  }
  others <- Filter(function(r) !identical(r$id, id), records)
  # The lists shrink, then the claim's fields, until the document fits.
  steps <- list(
    list(records = 20L, pending = 8L, tests = 5L, claim = 400L),
    list(records = 10L, pending = 8L, tests = 5L, claim = 400L),
    list(records = 5L, pending = 4L, tests = 3L, claim = 300L),
    list(records = 3L, pending = 2L, tests = 2L, claim = 200L),
    list(records = 0L, pending = 1L, tests = 1L, claim = 120L),
    list(records = 0L, pending = 0L, tests = 0L, claim = 80L)
  )
  for (step in steps) {
    doc$records <- lapply(utils::head(others, step$records), function(r) {
      list(id = r$id, title = host_cut(r$title, 80L), review = r$review)
    })
    doc$records_more <- max(0L, length(others) - step$records)
    doc$pending <- lapply(utils::head(pending, step$pending), function(p) {
      p$at <- NULL
      p
    })
    doc$pending_more <- max(0L, length(pending) - step$pending)
    if (!is.null(x)) {
      stated <- utils::tail(x$revisions, 1)[[1]]$claim
      doc$claim <- list(
        id = stated$id,
        wording = host_cut(stated$wording, step$claim),
        target = host_cut(stated$target, step$claim),
        scope = host_cut(stated$scope, step$claim),
        units = host_cut(stated$units, step$claim),
        horizon = host_cut(stated$horizon, step$claim)
      )
      doc$latest <- list(
        fit = host_last_id(x$regressions),
        design = host_last_id(x$research_designs),
        tests = utils::head(tests, step$tests),
        tests_more = max(0L, length(tests) - step$tests)
      )
    }
    if (host_json_size(doc) <= host_state_budget - 40L) {
      break
    }
  }
  doc$revision <- host_state_revision(store, key, doc)
  doc
}

# The document's own revision: one sequence per conversation, which rises
# whenever a tab's document changes, so the pane and the model's status read
# one order and a reload does not restart it.
host_state_revision <- function(store, key, doc) {
  doc$revision <- NULL
  doc$instance <- NULL
  digest <- object_id(doc)
  state <- host_conversation(store, key)
  seen <- state$documents[[key$session]]
  if (identical(seen$digest, digest)) {
    return(seen$revision)
  }
  state$revision <- (state$revision %||% 0L) + 1L
  state$documents[[key$session]] <- list(
    digest = digest,
    revision = state$revision
  )
  host_conversation_write(store, key, state)
  state$revision
}

# The document in one line, for hosts that read text.
host_state_text <- function(doc) {
  if (is.null(doc$record)) {
    return(paste(
      "No Suppose record in this project yet; the scientist's first typed words start one.",
      doc$approval
    ))
  }
  counts <- doc$pending_counts
  count <- function(n, one, many = paste0(one, "s")) {
    if (n) sprintf("%d %s", n, if (n == 1L) one else many)
  }
  parts <- c(
    count(counts$ready, "draft awaiting review", "drafts awaiting review"),
    count(
      counts$stale,
      "draft on an earlier revision",
      "drafts on an earlier revision"
    ),
    count(counts$drafting, "draft being written", "drafts being written"),
    count(doc$retained$observations, "attached measurement set"),
    count(doc$retained$regressions, "regression"),
    count(length(doc$latest$tests) + doc$latest$tests_more, "open test")
  )
  sprintf(
    "Suppose record %s (%s, state %d), %s: \"%s\"%s. %s",
    doc$record$title %||% doc$record$id,
    doc$record$id,
    doc$record$state_revision,
    doc$review,
    host_cut(doc$claim$wording, 100L) %||% "",
    if (length(parts)) paste0("; ", paste(parts, collapse = ", ")) else "",
    doc$approval
  )
}

host_read_sections <- c(
  "claim",
  "judgments",
  "pending",
  "records",
  "observations",
  "predictor_datasets",
  "updates",
  "prospective_tests",
  "sensitivities",
  "model_extensions",
  "regressions",
  "research_designs",
  "regression_tests",
  "regression_sensitivities",
  "model_worlds",
  "model_implications",
  "model_references"
)

# One section of the record, a page at a time. A page holds whole items up to
# `page_chars` characters of JSON; an item longer than a page comes in parts,
# each a page of its JSON. Each page carries the section's `revision`; every
# later page needs it back, and is refused if the section has changed.
# `pending` and `records` are the conversation's and the project's.
host_read_inquiry <- function(
  store,
  key,
  section,
  page = 1L,
  page_chars = host_state_budget,
  revision = NULL
) {
  section <- rlang::arg_match0(section, host_read_sections)
  check_count(page, "page")
  check_text(revision, "revision", optional = TRUE)
  # Without the revision, a later page could not tell that the section had
  # changed since page 1, and would lose or repeat items.
  if (page > 1L && is.null(revision)) {
    abort_suppose(
      "Pass the {.arg revision} page 1 of {.val {section}} gave to read page {page}.",
      arg = "revision"
    )
  }
  items <- if (identical(section, "records")) {
    lapply(host_records(store, key), function(r) {
      r[c("id", "title", "review", "revisions", "state_revision", "updated_at")]
    })
  } else {
    id <- host_turn_record(store, key)
    if (is.null(id)) {
      abort_suppose(
        "This project has no Suppose record yet. One starts from the scientist's first typed words.",
        "no_record"
      )
    }
    if (identical(section, "pending")) {
      lapply(host_pending(store, key, open = id), function(p) {
        d <- if (!is.null(p$draft)) host_draft_read(store, key, p$draft)
        p$summary <- if (!is.null(d$proposal)) {
          list(
            claim = plain(d$proposal$claim[c(
              "wording",
              "target",
              "scope",
              "units",
              "horizon",
              "expectations",
              "assumptions",
              "unresolved"
            )]),
            sources = plain(d$proposal$changes$sources),
            ideas = plain(d$proposal$changes$ideas),
            preview_issue = d$proposal$preview_issue
          )
        } else if (!is.null(d$form)) {
          list(
            form = d$form$form,
            provided_fields = d$form$provided_fields,
            defaulted_fields = d$form$defaulted_fields,
            source_quote = d$form$source_quote
          )
        }
        p
      })
    } else {
      x <- host_record_read(store, key, id)
      e <- utils::tail(x$revisions, 1)[[1]]
      switch(
        section,
        # With the numerical model retained beside the claim, if any: the
        # fitted prior and its prediction's summary, not its draws.
        claim = list(c(
          plain(e$claim),
          list(
            review = host_review(x),
            candidate = plain(e$candidate),
            prediction = plain(e$prediction[setdiff(
              names(e$prediction),
              "draws"
            )])
          )
        )),
        judgments = plain(e$judgments),
        observations = observation_inventory(x),
        predictor_datasets = plain(x$predictors),
        updates = update_inventory(x),
        prospective_tests = test_inventory(x),
        sensitivities = plain(x$sensitivities),
        model_extensions = plain(x$model_extensions),
        regressions = regression_inventory(x),
        research_designs = research_design_inventory(x),
        regression_tests = regression_test_inventory(x),
        regression_sensitivities = plain(x$regression_sensitivities),
        model_worlds = lapply(x$model_worlds, world_inventory),
        model_implications = plain(x$model_implications),
        model_references = plain(x$model_references)
      )
    }
  }
  items <- lapply(items %||% list(), plain)
  json_of <- function(i) {
    as.character(jsonlite::toJSON(
      i,
      auto_unbox = TRUE,
      null = "null",
      na = "null",
      digits = NA
    ))
  }
  texts <- vapply(items, json_of, character(1))
  # What the section held when these pages were cut: a page read against a
  # different revision could lose or repeat items, so it is refused.
  section_revision <- substr(object_id(texts), 1L, 12L)
  if (!is.null(revision) && !identical(revision, section_revision)) {
    abort_suppose(
      "Section {.val {section}} has changed since its first page was read. Read it again from page 1.",
      "stale"
    )
  }
  # An item longer than a page is read in parts, each a page of its JSON.
  parts <- list()
  for (i in seq_along(items)) {
    n <- nchar(texts[[i]])
    if (n <= page_chars) {
      parts[[length(parts) + 1L]] <- list(
        item = i,
        value = items[[i]],
        size = n
      )
      next
    }
    chunks <- host_json_chunks(texts[[i]], page_chars)
    count <- length(chunks)
    for (k in seq_len(count)) {
      parts[[length(parts) + 1L]] <- list(
        item = i,
        value = list(item = i, part = k, parts = count, json = chunks[[k]]),
        size = sum(host_json_cost(strsplit(chunks[[k]], "")[[1]]))
      )
    }
  }
  # Whole items (or parts) per page, greedily, and at least one.
  pages <- integer(length(parts))
  current <- 1L
  used <- 0
  for (j in seq_along(parts)) {
    if (used > 0 && used + parts[[j]]$size > page_chars) {
      current <- current + 1L
      used <- 0
    }
    pages[[j]] <- current
    used <- used + parts[[j]]$size
  }
  total <- if (length(parts)) max(pages) else 1L
  if (page > total) {
    abort_suppose(
      "Section {.val {section}} has {total} page{?s}.",
      "page"
    )
  }
  list(
    section = section,
    revision = section_revision,
    page = as.integer(page),
    pages = total,
    items = lapply(parts[pages == page], `[[`, "value"),
    total = length(items)
  )
}
