state_fixture <- function(env = parent.frame()) {
  store <- host_store(withr::local_tempdir(.local_envir = env))
  key <- function(session = "tab-1", turn = NULL) {
    host_key("ada", "cure-protocol", "c-1", session, turn)
  }
  list(store = store, key = key)
}

fake_draft <- function(store, key, n, record, kind = "interpretation") {
  turn <- list(
    record = record,
    turn = sprintf("t-%03d", n),
    session = "tab-1",
    base_digest = host_record_meta(store, key, record)$digest
  )
  id <- if (identical(kind, "interpretation")) {
    host_draft_write(
      store,
      key,
      turn,
      kind,
      proposal = list(id = sprintf("%012d%052d", n, 0L))
    )
  } else {
    host_draft_write(
      store,
      key,
      turn,
      kind,
      form = list(
        id = sprintf("%012d%052d", n, 0L),
        form = kind,
        provided_fields = "formula",
        source_quote = "Fit hardness against cure time."
      )
    )
  }
  # A draft is in review once its turn has settled with it.
  settled <- host_turn_read(store, key, turn$turn) %||%
    c(turn, list(version = 1L, state = "done", drafts = list()))
  settled$drafts <- c(unlist(settled$drafts), id)
  host_turn_write(store, key, settled)
  id
}

test_that("the state document fits its budget and counts what its lists leave out", {
  f <- state_fixture()
  k <- f$key()
  example <- suppose_worked_example("regression")
  host_record_write(
    f$store,
    k,
    "r-regression",
    example,
    title = "Cure time and hardness"
  )
  others <- vapply(
    seq_len(25),
    function(i) {
      host_record_new(
        f$store,
        k,
        sprintf("Belief number %d about coatings.", i),
        "ada"
      )
    },
    character(1)
  )
  host_open_record(f$store, k, "r-regression")
  for (i in seq_len(12)) {
    fake_draft(f$store, k, i, if (i %% 2) "r-regression" else others[[i]])
  }
  doc <- host_state(f$store, k)
  expect_identical(doc$schema, "suppose/state@1")
  expect_lte(host_json_size(doc), host_state_budget)
  expect_identical(doc$record$id, "r-regression")
  expect_identical(doc$record$title, "Cure time and hardness")
  expect_identical(length(doc$records) + doc$records_more, 25L)
  expect_lte(length(doc$records), 20L)
  expect_identical(length(doc$pending) + doc$pending_more, 12L)
  expect_lte(length(doc$pending), 8L)
  # Drafts on the open record come first.
  expect_identical(doc$pending[[1]]$record, "r-regression")
  expect_true(doc$pending[[1]]$ready)
  expect_true(doc$pending[[1]]$current)
  expect_identical(doc$retained$regressions, 2L)
  expect_identical(doc$latest$fit, utils::tail(example$regressions, 1)[[1]]$id)
  expect_identical(doc$review, host_review(example))
  expect_identical(doc$quotes, "host-verified")
  expect_match(doc$approval, "Only the scientist's buttons")
  expect_false(any(grepl("Use |Ask |Never ", doc$limitations)))
  expect_false(is.null(doc$last_decision$what))
  # The same record in the workbench's own summary runs to about 8,000.
  expect_gt(
    nchar(jsonlite::toJSON(
      plain(inquiry_context_summary(list(
        base = example,
        changes = proposal_changes(),
        form_state = list()
      ))),
      auto_unbox = TRUE,
      null = "null",
      digits = NA
    )),
    host_state_budget
  )
})

test_that("the document's revision rises only when it changes, in one sequence per conversation", {
  f <- state_fixture()
  k <- f$key()
  id <- host_record_new(f$store, k, "A longer cure helps.", "ada")
  host_open_record(f$store, k, id)
  first <- host_state(f$store, k)$revision
  expect_identical(host_state(f$store, k, instance = "pane-7")$revision, first)
  fake_draft(f$store, k, 1, id)
  second <- host_state(f$store, k)$revision
  expect_identical(second, first + 1L)
  host_set_editing(f$store, k, "regression", unsaved = TRUE)
  editing <- host_state(f$store, k)
  expect_identical(editing$revision, second + 1L)
  expect_identical(editing$editing$form, "regression")
  expect_true(editing$editing$unsaved)
  # Another tab reads the next number in the same sequence.
  expect_identical(host_state(f$store, f$key("tab-2"))$revision, second + 2L)
  expect_identical(host_state(f$store, k)$revision, second + 1L)
})

test_that("staged work shows as not ready until its turn is done", {
  skip_if_not_installed("ellmer")
  f <- state_fixture()
  words <- list(
    items = list(list(
      turn = "t-01",
      via = "typed",
      text = "A longer cure may make this coating more durable."
    ))
  )
  host_call_tool(
    f$store,
    f$key(turn = "t-01"),
    words,
    "propose_interpretation",
    list(
      wording = "A longer cure may make this coating more durable.",
      source_quote = "A longer cure may make this coating more durable.",
      reason = "As stated."
    )
  )
  doc <- host_state(f$store, f$key())
  expect_length(doc$pending, 1L)
  expect_false(doc$pending[[1]]$ready)
  expect_null(doc$pending[[1]]$draft)
  expect_match(host_state_text(doc), "1 draft being written")
  host_settle_turn(f$store, f$key(turn = "t-01"), "done")
  doc <- host_state(f$store, f$key())
  expect_true(doc$pending[[1]]$ready)
  expect_match(doc$pending[[1]]$draft, "^d-")
  text <- host_state_text(doc)
  expect_match(text, doc$record$id, fixed = TRUE)
  expect_match(text, "1 draft awaiting review")
  expect_match(text, "unreviewed")
  page <- host_read_inquiry(f$store, f$key(), "pending")
  expect_identical(
    page$items[[1]]$summary$claim$wording,
    "A longer cure may make this coating more durable."
  )
  expect_identical(
    page$items[[1]]$summary$sources[[1]]$quote,
    words$items[[1]]$text
  )
})

test_that("read_inquiry gives one section at a time, in pages", {
  f <- state_fixture()
  k <- f$key()
  expect_error(
    host_read_inquiry(f$store, k, "claim"),
    class = "suppose_no_record"
  )
  expect_match(host_state_text(host_state(f$store, k)), "No Suppose record")
  for (i in seq_len(6)) {
    host_record_new(
      f$store,
      k,
      sprintf("Belief number %d about coatings.", i),
      "ada"
    )
  }
  one <- host_read_inquiry(f$store, k, "records", page_chars = 400L)
  expect_gt(one$pages, 1L)
  expect_identical(one$total, 6L)
  last <- host_read_inquiry(
    f$store,
    k,
    "records",
    page = one$pages,
    page_chars = 400L,
    revision = one$revision
  )
  expect_gte(length(last$items), 1L)
  expect_error(
    host_read_inquiry(
      f$store,
      k,
      "records",
      page = one$pages + 1L,
      page_chars = 400L,
      revision = one$revision
    ),
    class = "suppose_page"
  )
  # A page is a whole number of characters, large enough to hold one.
  for (bad in list(NA_real_, "big", 1L, 99L, 250.5, c(400L, 500L))) {
    expect_error(
      host_read_inquiry(f$store, k, "records", page_chars = bad),
      class = "suppose_input"
    )
  }
  # A later page needs the revision page 1 gave, and page 1's page size.
  expect_error(
    host_read_inquiry(f$store, k, "records", page = 2L, page_chars = 400L),
    class = "suppose_input"
  )
  expect_error(
    host_read_inquiry(
      f$store,
      k,
      "records",
      page = 2L,
      revision = one$revision
    ),
    class = "suppose_stale"
  )
  claim <- host_read_inquiry(f$store, k, "claim")
  expect_identical(claim$items[[1]]$review, "unreviewed")
  expect_match(claim$items[[1]]$wording, "^Belief number")
  expect_identical(host_read_inquiry(f$store, k, "regressions")$total, 0L)
  expect_error(host_read_inquiry(f$store, k, "everything"))
  # Whole items share a page when they fit.
  expect_length(
    host_read_inquiry(f$store, k, "records", page_chars = 1e5)$items,
    6L
  )
  # An item longer than a page is read in parts that put it back together.
  first <- host_read_inquiry(f$store, k, "claim", page_chars = 250L)
  expect_gt(first$pages, 1L)
  json <- vapply(
    seq_len(first$pages),
    function(p) {
      got <- host_read_inquiry(
        f$store,
        k,
        "claim",
        page = p,
        page_chars = 250L,
        revision = first$revision
      )
      paste(vapply(got$items, `[[`, "", "json"), collapse = "")
    },
    character(1)
  )
  whole <- jsonlite::fromJSON(
    paste(json, collapse = ""),
    simplifyVector = FALSE
  )
  expect_match(whole$wording, "^Belief number")
  # A part is cut by its size once written as JSON, so quotes and
  # backslashes cannot push it past its page.
  quoted <- paste0("{\"q\":\"", strrep("\\\"", 400), strrep("x", 300), "\"}")
  parts <- host_json_chunks(quoted, 250L)
  expect_identical(paste(parts, collapse = ""), quoted)
  written <- vapply(
    parts,
    function(p) nchar(jsonlite::toJSON(p, auto_unbox = TRUE)) - 2L,
    integer(1)
  )
  expect_true(all(written <= 250L))
  expect_identical(
    host_json_chunks("\u0001a", 6L),
    c("\u0001", "a")
  )
  # A page read against a section that has changed is refused.
  host_record_new(f$store, k, "Belief number 7 about coatings.", "ada")
  expect_error(
    host_read_inquiry(
      f$store,
      k,
      "records",
      page = 2L,
      page_chars = 400L,
      revision = one$revision
    ),
    class = "suppose_stale"
  )
})

test_that("open tests are listed soonest first; assessed and replaced ones are not", {
  x <- list(
    commitments = list(
      list(id = "a", horizon = "2026-12-01T00:00:00Z"),
      list(id = "b", horizon = "2026-10-01T00:00:00Z"),
      list(id = "c", horizon = "2026-11-01T00:00:00Z"),
      list(id = "d", horizon = "2026-12-15T00:00:00Z", replaces = "a")
    ),
    assessments = list(
      list(commitment_id = "c", status = "within_prediction"),
      list(commitment_id = "b", status = "awaiting_outcomes")
    ),
    regression_commitments = list(list(
      id = "r1",
      horizon = "2026-10-15T00:00:00Z"
    ))
  )
  open <- host_open_tests(x)
  expect_identical(vapply(open, `[[`, "", "id"), c("b", "r1", "d"))
  # Deadlines are compared as times: a fraction of a second is later.
  same_second <- list(
    commitments = list(
      list(id = "late", horizon = "2026-10-01T12:00:00.5Z"),
      list(id = "early", horizon = "2026-10-01T12:00:00Z")
    )
  )
  expect_identical(
    vapply(host_open_tests(same_second), `[[`, "", "id"),
    c("early", "late")
  )
  expect_identical(
    host_time(c("2026-10-01T12:00:00Z", "2026-10-01T12:00:00.5Z", "soon")) -
      host_time("2026-10-01T12:00:00Z"),
    c(0, 0.5, NA)
  )
  expect_identical(open[[2]]$kind, "regression")
})

test_that("drafts on an earlier revision are counted apart from those awaiting review", {
  f <- state_fixture()
  k <- f$key()
  id <- host_record_new(f$store, k, "A longer cure helps.", "ada")
  host_open_record(f$store, k, id)
  fake_draft(f$store, k, 1, id)
  expect_true(host_state(f$store, k)$pending[[1]]$current)
  expect_match(
    host_state_text(host_state(f$store, k)),
    "1 draft awaiting review"
  )
  x <- accept_interpretation(
    host_record_read(f$store, k, id),
    "ada",
    "It says what I mean.",
    "A shorter cure may do."
  )
  host_record_write(f$store, k, id, x)
  doc <- host_state(f$store, k)
  expect_false(doc$pending[[1]]$current)
  expect_identical(doc$pending_counts$stale, 1L)
  text <- host_state_text(doc)
  expect_match(text, "1 draft on an earlier revision")
  expect_false(grepl("awaiting review", text))
})

test_that("the last decision is the latest, assessments included", {
  x <- suppose_worked_example("plants")
  last <- host_last_decision(x, 3L)
  stamps <- unlist(lapply(
    c(x$observations, x$updates, x$sensitivities),
    `[[`,
    "created_at"
  ))
  expect_identical(last$at, max(stamps))
  expect_identical(last$state_revision, 3L)
  assessed <- list(
    revisions = x$revisions,
    commitments = list(list(id = "c1", created_at = "2026-01-01T00:00:00Z")),
    assessments = list(list(
      commitment_id = "c1",
      status = "within_prediction",
      assessed_at = "2099-01-01T00:00:00Z"
    ))
  )
  latest <- host_last_decision(assessed, 1L)
  expect_identical(latest$what, "assessed a test")
  expect_identical(latest$outcome, "within_prediction")
  attached <- list(
    revisions = x$revisions,
    regression_commitments = list(
      list(id = "c2", author = "ada", created_at = "2098-01-01T00:00:00Z")
    ),
    regression_test_data = list(
      list(author = "bo", created_at = "2098-02-01T00:00:00Z")
    )
  )
  latest <- host_last_decision(attached, 1L)
  expect_identical(latest$what, "attached regression test data")
  expect_identical(latest$by, "bo")
  # A model world is stamped in its provenance.
  world <- list(
    revisions = x$revisions,
    model_worlds = list(
      list(id = "w1", provenance = list(created_at = "2099-03-01T00:00:00Z"))
    )
  )
  latest <- host_last_decision(world, 1L)
  expect_identical(latest$what, "added a model world")
  expect_identical(latest$at, "2099-03-01T00:00:00Z")
})

test_that("a revision made by hand is a decision too", {
  x <- suppose_worked_example("plants")
  last <- utils::tail(x$revisions, 1)[[1]]
  revised <- revise_claim(
    last$claim,
    "bo",
    "Narrower scope.",
    scope = "Only the pilot line"
  )
  y <- record_revision(x, revised, reason = "Narrower scope.")
  latest <- host_last_decision(y, 4L)
  expect_identical(
    latest$what,
    sprintf("revised the claim in revision %d", length(y$revisions))
  )
  expect_identical(latest$by, "bo")
  synthetic <- list(
    revisions = list(
      list(
        claim = list(id = "c1", created_at = "2026-01-01T00:00:00Z"),
        judgments = list()
      ),
      list(
        claim = list(id = "c1"),
        judgments = list(
          list(id = "j1", author = "bo", created_at = "2026-02-01T00:00:00Z")
        )
      ),
      list(
        claim = list(id = "c1"),
        judgments = list(list(id = "j1")),
        candidate = list(id = "p1", created_at = "2026-03-01T00:00:00Z")
      )
    )
  )
  expect_identical(
    host_last_decision(synthetic, 1L)$what,
    "fitted a candidate in revision 3"
  )
  synthetic$revisions[[3]]$candidate <- NULL
  latest <- host_last_decision(synthetic, 1L)
  expect_identical(latest$what, "retained a judgment in revision 2")
  expect_identical(latest$by, "bo")
  # A revision that adds nothing stamped (it clears the fit) is dated by when
  # the store first wrote it.
  cleared <- host_last_decision(
    synthetic,
    1L,
    revised_at = c("", "", "2026-04-01T00:00:00Z")
  )
  expect_identical(cleared$what, "revised the record in revision 3")
  expect_identical(cleared$at, "2026-04-01T00:00:00Z")
  # Stamps are compared as times: a fraction of a second is later.
  timed <- list(
    revisions = list(list(
      claim = list(id = "c1", created_at = "2026-01-01T12:00:00Z")
    )),
    observations = list(list(id = "o1", created_at = "2026-01-01T12:00:00.5Z")),
    assessments = list(list(
      commitment_id = "t1",
      status = "within_prediction",
      assessed_at = "2026-01-01T12:00:00Z"
    ))
  )
  expect_identical(host_last_decision(timed, 1L)$what, "attached measurements")
})

test_that("the store dates each revision when it first writes it", {
  f <- state_fixture()
  k <- f$key()
  x <- suppose_worked_example("plants")
  host_record_write(f$store, k, "r1", x)
  first <- host_record_meta(f$store, k, "r1")
  # What the record already had is not dated by this write.
  expect_identical(unique(as.character(unlist(first$revised_at))), "")
  last <- utils::tail(x$revisions, 1)[[1]]
  y <- record_revision(
    x,
    revise_claim(last$claim, "bo", "Narrower.", scope = "Only the pilot line"),
    reason = "Narrower."
  )
  host_record_write(f$store, k, "r1", y)
  second <- as.character(unlist(host_record_meta(f$store, k, "r1")$revised_at))
  expect_length(second, length(y$revisions))
  expect_match(utils::tail(second, 1), "^[0-9]{4}-[0-9]{2}-[0-9]{2}T")
  expect_identical(utils::head(second, -1), rep("", length(x$revisions)))
})

test_that("the claim section carries its retained numerical model, not the draws", {
  f <- state_fixture()
  k <- f$key()
  x <- suppose_worked_example("plants")
  e <- utils::tail(x$revisions, 1)[[1]]
  skip_if(is.null(e$candidate) || is.null(e$prediction))
  host_record_write(f$store, k, "r-plants", x)
  host_open_record(f$store, k, "r-plants")
  item <- host_read_inquiry(f$store, k, "claim", page_chars = 1e6)$items[[1]]
  expect_identical(item$candidate$method, e$candidate$method)
  expect_equal(
    item$prediction$summary$mean_difference$mean,
    e$prediction$summary$mean_difference$mean
  )
  expect_null(item$prediction$draws)
})

test_that("fields are cut by their size as JSON, so escapes cannot pass the budget", {
  f <- state_fixture()
  long <- strrep("\"", host_id_limit %/% 2L)
  k <- host_key(long, long, long, long, long, long)
  escaped <- strrep("\u0001\"\\", 2000)
  x <- accept_interpretation(
    elicitation_record(claim(escaped, "ada"), "One"),
    escaped,
    "It says what I mean.",
    "A shorter cure holds up as well."
  )
  host_record_write(f$store, k, long, x, title = escaped)
  host_set_editing(f$store, k, form = escaped, unsaved = TRUE)
  doc <- host_state(f$store, k, instance = long)
  expect_lte(host_json_size(doc), host_state_budget)
  written <- function(v) nchar(jsonlite::toJSON(v, auto_unbox = TRUE)) - 2L
  expect_lte(written(doc$last_decision$by), 80L)
  expect_lte(written(doc$editing$form), 80L)
  expect_lte(written(doc$record$title), 120L)
  expect_identical(host_cut("plain", 80L), "plain")
  expect_identical(host_cut(strrep("\u0001", 20), 13L), "\u0001\u0001\u2026")
  # A decision without an author keeps the key.
  expect_true(
    "by" %in%
      names(host_last_decision(
        list(
          revisions = list(list(
            acceptance = list(created_at = "2026-01-01T00:00:00Z")
          ))
        ),
        1L
      ))
  )
})

test_that("sizes are counted as the host counts them, an emoji taking two", {
  emoji <- "\U0001F600"
  expect_identical(host_utf16_length(emoji), 2L)
  expect_identical(host_utf16_length("ab"), 2L)
  expect_identical(host_json_cost(c("a", emoji, "\"")), c(1L, 2L, 2L))
  expect_identical(
    host_cut(strrep(emoji, 100), 13L),
    paste0(strrep(emoji, 6), "\u2026")
  )
  expect_identical(
    host_json_chunks(strrep(emoji, 10), 6L),
    c(rep(strrep(emoji, 3), 3), emoji)
  )
  f <- state_fixture()
  k <- f$key()
  wide <- strrep(emoji, 5000)
  x <- accept_interpretation(
    elicitation_record(claim(wide, "ada"), "One"),
    wide,
    "It says what I mean.",
    "A shorter cure holds up as well."
  )
  host_record_write(f$store, k, "emoji", x, title = wide)
  host_set_editing(f$store, k, form = wide, unsaved = TRUE)
  doc <- host_state(f$store, k)
  expect_lte(host_json_size(doc), host_state_budget)
  expect_gt(
    host_json_size(doc),
    nchar(jsonlite::toJSON(
      doc,
      auto_unbox = TRUE,
      null = "null",
      pretty = TRUE
    ))
  )
})

test_that("the document stays within its budget whatever the host's ids and names", {
  f <- state_fixture()
  long <- strrep("x", host_id_limit)
  k <- host_key(long, long, long, long, long, long)
  x <- accept_interpretation(
    elicitation_record(claim(strrep("A long belief. ", 400), "ada"), "One"),
    strrep("y", 5000),
    "It says what I mean.",
    "A shorter cure holds up as well."
  )
  host_record_write(f$store, k, long, x, title = strrep("t", 5000))
  host_set_editing(f$store, k, form = strrep("f", 5000), unsaved = TRUE)
  doc <- host_state(f$store, k, instance = long)
  expect_lte(host_json_size(doc), host_state_budget)
  expect_identical(doc$instance, long)
  expect_identical(nchar(doc$last_decision$by), 80L)
  expect_identical(nchar(doc$editing$form), 80L)
  # Ids are measured as JSON writes them, and control characters are refused.
  quoted <- strrep("\"", host_id_limit %/% 2L)
  expect_identical(host_state(f$store, k, instance = quoted)$instance, quoted)
  expect_error(
    host_state(f$store, k, instance = paste0(quoted, "\"")),
    class = "suppose_input"
  )
  expect_error(
    host_key("ada", "p", "c", "tab-1", "t-\u0001"),
    class = "suppose_input"
  )
  too_long <- strrep("x", host_id_limit + 1L)
  expect_error(
    host_state(f$store, k, instance = too_long),
    class = "suppose_input"
  )
  expect_error(
    host_key("ada", "p", "c", "tab-1", too_long),
    class = "suppose_input"
  )
  expect_error(
    host_record_write(f$store, k, too_long, x),
    class = "suppose_input"
  )
})
