host_fixture <- function() {
  store <- host_store(withr::local_tempdir(.local_envir = parent.frame()))
  key <- function(turn, session = "tab-1", conversation = "c-1") {
    host_key("ada", "cure-protocol", conversation, session, turn)
  }
  list(store = store, key = key)
}

typed <- function(text, turn = "t-01") {
  list(
    items = list(list(turn = turn, via = "typed", text = text)),
    truncated = FALSE
  )
}

propose <- function(
  wording = "A longer cure may make this coating more durable."
) {
  list(
    wording = wording,
    source_quote = "A longer cure may make this coating more durable.",
    reason = "The scientist's hunch, as stated."
  )
}

test_that("a host's first typed words start the project's record", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  expect_error(
    host_call_tool(
      f$store,
      f$key("t-01"),
      list(items = list(list(via = "suggestion", text = "Screen solvents"))),
      "read_inquiry"
    ),
    class = "suppose_no_record"
  )
  out <- host_call_tool(
    f$store,
    f$key("t-02"),
    typed("A longer cure may make this coating more durable.", "t-02"),
    "read_inquiry"
  )
  records <- host_records(f$store, f$key("t-02"))
  expect_length(records, 1L)
  expect_identical(out$record, records[[1]]$id)
  x <- host_record_read(f$store, f$key("t-02"), out$record)
  expect_identical(
    x$revisions[[1]]$claim$wording,
    "A longer cure may make this coating more durable."
  )
  expect_identical(x$revisions[[1]]$claim$author, "ada")
  expect_identical(records[[1]]$title, "My inquiry")
  expect_identical(host_current_record(f$store, f$key("t-03")), out$record)
})

test_that("a draft reaches review only when its turn is done", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  expect_length(host_drafts(f$store, f$key("t-01")), 0L)
  turn <- host_turn_read(f$store, f$key("t-01"), "t-01")
  expect_identical(turn$state, "running")
  expect_true(turn$changed)

  settled <- host_settle_turn(f$store, f$key("t-01"), "done")
  expect_identical(settled$state, "done")
  drafts <- host_drafts(f$store, f$key("t-01"))
  expect_length(drafts, 1L)
  expect_identical(drafts[[1]]$kind, "interpretation")
  expect_identical(drafts[[1]]$turn, "t-01")
  expect_s3_class(drafts[[1]]$proposal, "suppose_proposal")
  expect_identical(
    drafts[[1]]$proposal$claim$wording,
    "A longer cure may make this coating more durable."
  )
  # The words' source goes into the draft's provenance.
  expect_identical(drafts[[1]]$proposal$context$messages[[1]]$via, "typed")
  expect_identical(drafts[[1]]$proposal$context$provider, "host")
  # A settled turn cannot change, and settling it again changes nothing.
  expect_error(
    host_call_tool(f$store, f$key("t-01"), words, "read_inquiry"),
    class = "suppose_cancelled"
  )
  expect_identical(
    host_settle_turn(f$store, f$key("t-01"), "stopped")$state,
    "done"
  )
})

test_that("a stopped or failed reply leaves nothing to review", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  expect_identical(
    host_settle_turn(f$store, f$key("t-01"), "stopped")$state,
    "stopped"
  )
  host_call_tool(
    f$store,
    f$key("t-02"),
    words,
    "propose_interpretation",
    propose()
  )
  expect_identical(
    host_settle_turn(f$store, f$key("t-02"), "failed")$state,
    "failed"
  )
  expect_length(host_drafts(f$store, f$key("t-03")), 0L)
})

test_that("the words are the host's, and quotes are checked against them", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(f$store, f$key("t-01"), words, "read_inquiry")
  bad <- propose()
  bad$source_quote <- "Cure time does not matter."
  expect_error(
    host_call_tool(
      f$store,
      f$key("t-01"),
      words,
      "propose_interpretation",
      bad
    ),
    "Quote the user's message exactly"
  )
  expect_error(
    host_call_tool(
      f$store,
      f$key("t-01"),
      list(items = list(list(via = "model", text = "I said so"))),
      "read_inquiry"
    ),
    class = "suppose_source"
  )
  expect_error(
    host_call_tool(f$store, f$key("t-01"), words, "apply_interpretation"),
    class = "suppose_unknown_tool"
  )
})

test_that("a later turn from the same tab ends an unreported one; another tab's does not", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  host_call_tool(
    f$store,
    f$key("t-02", session = "tab-2"),
    words,
    "read_inquiry"
  )
  host_call_tool(f$store, f$key("t-03"), words, "read_inquiry")
  expect_identical(
    host_turn_read(f$store, f$key("t-01"), "t-01")$state,
    "cancelled"
  )
  expect_identical(
    host_turn_read(f$store, f$key("t-02"), "t-02")$state,
    "running"
  )
  # A report that arrives late changes nothing.
  host_settle_turn(f$store, f$key("t-01"), "done")
  expect_length(host_drafts(f$store, f$key("t-01")), 0L)
  # The scientist can discard what a tab that never came back staged.
  expect_identical(
    host_discard_turn(f$store, f$key("t-02"), "t-02")$state,
    "discarded"
  )
  expect_error(
    host_settle_turn(f$store, f$key("t-03", session = "tab-2"), "done"),
    class = "suppose_cancelled"
  )
})

test_that("a call from a turn older than one its tab already began stages nothing", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.", "t-02")
  host_call_tool(
    f$store,
    f$key("t-02"),
    words,
    "propose_interpretation",
    propose()
  )
  host_settle_turn(f$store, f$key("t-02"), "done")
  expect_error(
    host_call_tool(
      f$store,
      f$key("t-01"),
      words,
      "propose_interpretation",
      propose("A shorter cure is as durable.")
    ),
    class = "suppose_cancelled"
  )
  expect_identical(
    host_turn_read(f$store, f$key("t-01"), "t-01")$state,
    "cancelled"
  )
  # Its late report changes nothing, and the later turn's draft stands.
  host_settle_turn(f$store, f$key("t-01"), "done")
  drafts <- host_drafts(f$store, f$key("t-01"))
  expect_length(drafts, 1L)
  expect_identical(drafts[[1]]$turn, "t-02")
  # Another tab's turns are its own.
  expect_no_error(
    host_call_tool(
      f$store,
      f$key("t-00", session = "tab-2"),
      words,
      "read_inquiry"
    )
  )
})

test_that("a publication that fails part way leaves nothing of its turn in review", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  host_settle_turn(f$store, f$key("t-01"), "done")
  first <- host_drafts(f$store, f$key("t-01"))[[1]]
  words2 <- typed("A longer cure may make this coating more durable.", "t-02")
  host_call_tool(
    f$store,
    f$key("t-02"),
    words2,
    "propose_interpretation",
    propose("A longer cure makes this coating more durable.")
  )
  replace <- host_replace_drafts
  local_mocked_bindings(host_replace_drafts = function(...) {
    replace(...)
    stop("disk full")
  })
  settled <- host_settle_turn(f$store, f$key("t-02"), "done")
  expect_identical(settled$state, "failed")
  expect_match(settled$note, "disk full")
  ready <- host_drafts(f$store, f$key("t-02"))
  expect_length(ready, 1L)
  expect_identical(ready[[1]]$id, first$id)
  mine <- host_drafts(f$store, f$key("t-02"), status = NULL)
  mine <- Filter(function(d) identical(d$turn, "t-02"), mine)
  expect_identical(vapply(mine, `[[`, "", "status"), "failed")
})

test_that("a later turn's draft replaces the earlier one and keeps its changes", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  host_settle_turn(f$store, f$key("t-01"), "done")
  first <- host_drafts(f$store, f$key("t-01"))[[1]]
  more <- list(
    items = c(
      words$items,
      list(list(
        turn = "t-02",
        via = "ask_scientist",
        text = "Pencil hardness after 7 days."
      ))
    )
  )
  host_call_tool(f$store, f$key("t-02"), more, "preview_proposal")
  host_settle_turn(f$store, f$key("t-02"), "done")
  # Reading and previewing change nothing, so the draft stands.
  expect_identical(host_drafts(f$store, f$key("t-02"))[[1]]$id, first$id)

  args <- propose()
  args$unresolved <- list("How is durability measured?")
  host_call_tool(f$store, f$key("t-03"), more, "propose_interpretation", args)
  host_settle_turn(f$store, f$key("t-03"), "done")
  ready <- host_drafts(f$store, f$key("t-03"))
  expect_length(ready, 1L)
  expect_false(identical(ready[[1]]$id, first$id))
  expect_identical(
    host_draft_read(f$store, f$key("t-03"), first$id)$status,
    "superseded"
  )
  expect_identical(
    unlist(ready[[1]]$proposal$claim$unresolved),
    "How is durability measured?"
  )
})

test_that("a record changed during the reply keeps its drafts from review", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  out <- host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  x <- host_record_read(f$store, f$key("t-01"), out$record)
  x <- accept_interpretation(
    x,
    "ada",
    "It says what I mean.",
    "A shorter cure holds up as well."
  )
  before <- host_record_meta(f$store, f$key("t-01"), out$record)
  host_record_write(f$store, f$key("t-01"), out$record, x)
  after <- host_record_meta(f$store, f$key("t-01"), out$record)
  expect_identical(after$state_revision, before$state_revision + 1L)
  expect_identical(after$review, "interpretation")
  expect_error(
    host_call_tool(f$store, f$key("t-01"), words, "read_inquiry"),
    class = "suppose_stale"
  )
  settled <- host_settle_turn(f$store, f$key("t-01"), "done")
  expect_match(settled$note, "record changed")
  expect_length(host_drafts(f$store, f$key("t-01")), 0L)
})

test_that("tabs keep their own open record, and a new tab starts from the last opened", {
  f <- host_fixture()
  k1 <- f$key(NULL)
  first <- host_record_new(f$store, k1, "A longer cure helps.", "ada")
  second <- host_record_new(f$store, k1, "Humidity matters more.", "ada")
  host_open_record(f$store, k1, first)
  host_open_record(f$store, f$key(NULL, session = "tab-2"), second)
  expect_identical(host_current_record(f$store, k1), first)
  expect_identical(
    host_current_record(f$store, f$key(NULL, session = "tab-3")),
    second
  )
  expect_error(
    host_open_record(f$store, k1, "r-missing"),
    class = "suppose_no_record"
  )
  # Another conversation starts from the project's latest record.
  expect_identical(
    host_current_record(f$store, f$key(NULL, conversation = "c-2")),
    host_records(f$store, k1)[[1]]$id
  )
})

test_that("host ids become safe, distinct path segments", {
  expect_identical(host_segment("cure-protocol"), "cure-protocol")
  expect_match(host_segment("../../etc"), "^\\+etc-[0-9a-f]{12}$")
  expect_false(identical(host_segment("a b"), host_segment("a-b")))
  expect_true(host_before("t-01K6Z4N1", "t-01K6Z4R2"))
  expect_false(host_before("t-01K6Z4R2", "t-01K6Z4N1"))
  expect_false(host_before("t-1", "t-1"))
})

test_that("clearing a list is a change the turn can finish", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  args <- propose()
  # As JSON's [] arrives over MCP.
  args$unresolved <- list()
  host_call_tool(f$store, f$key("t-01"), words, "propose_interpretation", args)
  host_call_tool(f$store, f$key("t-01"), words, "preview_proposal")
  expect_identical(
    host_settle_turn(f$store, f$key("t-01"), "done")$state,
    "done"
  )
  d <- host_drafts(f$store, f$key("t-01"))[[1]]
  expect_identical(d$proposal$claim$unresolved, character())
})

test_that("a follow-up form draft keeps the settings it leaves out", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  k <- f$key(NULL)
  host_record_write(f$store, k, "r-reg", suppose_worked_example("regression"))
  host_open_record(f$store, k, "r-reg")
  first <- "Prepare the regression with location 42 and noise 7."
  words <- typed(first)
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "draft_regression",
    list(
      source_quote = first,
      reason = "As asked.",
      location = 42,
      noise_sd = 7
    )
  )
  host_settle_turn(f$store, f$key("t-01"), "done")
  second <- "Now use an effect SD of 3."
  more <- list(
    items = c(
      words$items,
      list(list(turn = "t-02", via = "typed", text = second))
    )
  )
  host_call_tool(
    f$store,
    f$key("t-02"),
    more,
    "draft_regression",
    list(source_quote = second, reason = "As asked.", effect_sd = 3)
  )
  host_settle_turn(f$store, f$key("t-02"), "done")
  ready <- host_drafts(f$store, k, kind = "regression")
  expect_length(ready, 1L)
  values <- ready[[1]]$form$values
  expect_equal(values$location, 42)
  expect_equal(values$noise_sd, 7)
  expect_equal(values$effect_sd, 3)
})

test_that("a turn that began before another tab's draft leaves that draft beside its own", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  words <- typed("A longer cure may make this coating more durable.")
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    propose()
  )
  host_settle_turn(f$store, f$key("t-01"), "done")
  a <- host_drafts(f$store, f$key("t-01"))[[1]]
  host_call_tool(f$store, f$key("t-02"), words, "read_inquiry")
  other <- propose()
  other$unresolved <- list("How is durability measured?")
  host_call_tool(
    f$store,
    f$key("t-03", session = "tab-2"),
    words,
    "propose_interpretation",
    other
  )
  host_settle_turn(f$store, f$key("t-03", session = "tab-2"), "done")
  mine <- propose()
  mine$ideas <- list("Measure pencil hardness after 7 days.")
  host_call_tool(f$store, f$key("t-02"), words, "propose_interpretation", mine)
  host_settle_turn(f$store, f$key("t-02"), "done")
  ready <- host_drafts(f$store, f$key(NULL))
  expect_setequal(vapply(ready, `[[`, "", "turn"), c("t-02", "t-03"))
  expect_identical(
    host_draft_read(f$store, f$key(NULL), a$id)$status,
    "superseded"
  )
})

test_that("a draft's provenance keeps every word its turn was given, with times", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  quote <- "A longer cure may make this coating more durable."
  host_call_tool(
    f$store,
    f$key("t-01"),
    typed(quote),
    "propose_interpretation",
    propose()
  )
  # A later call's window no longer holds the quoted words.
  later <- list(
    items = list(list(
      turn = "t-01",
      via = "ask_scientist",
      text = "Pencil hardness after 7 days."
    ))
  )
  host_call_tool(f$store, f$key("t-01"), later, "preview_proposal")
  host_settle_turn(f$store, f$key("t-01"), "done")
  d <- host_drafts(f$store, f$key("t-01"))[[1]]
  messages <- d$proposal$context$messages
  expect_identical(
    vapply(messages, `[[`, "", "text"),
    c(quote, "Pencil hardness after 7 days.")
  )
  expect_true(all(nzchar(vapply(messages, `[[`, "", "created_at"))))
  x <- host_record_read(f$store, f$key("t-01"), d$record)
  expect_no_error(record_conversation(x, messages))
})

test_that("a turn reported before Suppose saw it cannot start afterwards", {
  f <- host_fixture()
  host_settle_turn(f$store, f$key("t-01"), "stopped")
  expect_error(
    host_call_tool(
      f$store,
      f$key("t-01"),
      typed("A longer cure helps."),
      "read_inquiry"
    ),
    class = "suppose_cancelled"
  )
  expect_length(host_records(f$store, f$key(NULL)), 0L)
})

test_that("every word says where it came from, and the first record is this turn's", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  expect_error(
    host_call_tool(
      f$store,
      f$key("t-01"),
      list(items = list(list(text = "no source"))),
      "read_inquiry"
    ),
    class = "suppose_source"
  )
  words <- list(
    items = list(
      list(
        turn = "t-00",
        via = "typed",
        text = "Find recent papers on cure kinetics."
      ),
      list(
        turn = "t-01",
        via = "typed",
        text = "A longer cure may make this coating more durable."
      )
    )
  )
  out <- host_call_tool(f$store, f$key("t-01"), words, "read_inquiry")
  x <- host_record_read(f$store, f$key("t-01"), out$record)
  expect_identical(
    x$revisions[[1]]$claim$wording,
    "A longer cure may make this coating more durable."
  )
})

test_that("records never share a file, whatever their ids", {
  f <- host_fixture()
  k <- f$key(NULL)
  x <- elicitation_record(claim("First belief.", "ada"), "One")
  y <- elicitation_record(claim("Second belief.", "ada"), "Two")
  host_record_write(f$store, k, "x", x)
  host_record_write(f$store, k, "x.meta", y)
  expect_identical(
    host_record_read(f$store, k, "x")$revisions[[1]]$claim$wording,
    "First belief."
  )
  expect_identical(host_record_meta(f$store, k, "x")$id, "x")
  expect_setequal(
    vapply(host_records(f$store, k), `[[`, "", "id"),
    c("x", "x.meta")
  )
  expect_false(identical(
    host_segment("a b"),
    host_segment(sub("^\\+", "", host_segment("a b")))
  ))
  expect_match(host_segment("a b"), "^\\+")
})

test_that("a recorded analysis moves the state revision, not the drafts' basis", {
  skip_if_not_installed("deputy")
  f <- host_fixture()
  k <- f$key(NULL)
  x <- suppose_example()
  host_record_write(f$store, k, "x", x)
  before <- host_record_meta(f$store, k, "x")
  host_record_write(f$store, k, "x", host_record_read(f$store, k, "x"))
  expect_identical(
    host_record_meta(f$store, k, "x")$state_revision,
    before$state_revision
  )
  execution <- list(
    schema_version = 1L,
    code = "1 + 1",
    session_id = "s-1",
    execution_id = "e-1",
    generation = 1L,
    fresh = TRUE,
    reset_reason = NULL,
    outcome = "complete",
    segments = list(list(type = "output", text = "[1] 2"))
  )
  x <- record_analysis(x, execution, "Add", "fixture", "request1")
  host_record_write(f$store, k, "x", x)
  after <- host_record_meta(f$store, k, "x")
  expect_identical(after$state_revision, before$state_revision + 1L)
  expect_identical(after$digest, before$digest)
})

test_that("arguments arriving as JSON take the types the tool declares", {
  skip_if_not_installed("ellmer")
  tool <- ellmer::tool(
    function(xs, n, w) list(xs, n, w),
    name = "t",
    description = "t",
    arguments = list(
      xs = ellmer::type_array(ellmer::type_number()),
      n = ellmer::type_number(),
      w = ellmer::type_array(ellmer::type_string())
    )
  )
  got <- host_tool_arguments(
    tool,
    list(xs = list(0.5, 1, 2), n = list(3), w = list(), z = NULL)
  )
  expect_identical(got$xs, c(0.5, 1, 2))
  expect_identical(got$n, 3)
  expect_identical(got$w, character())
  expect_false("z" %in% names(got))
})

test_that("a turn builds on the draft awaiting review, as the workbench's suggestion does", {
  skip_if_not_installed("ellmer")
  f <- host_fixture()
  stated <- paste(
    "For panels cured at 60 and 90 min, the hardness in N: my central 90% interval",
    "for the 60 min mean is 10 to 14 and for the 90 min mean 12 to 18, with",
    "correlation 0.5, batch SDs 2 and 3, and a threshold of 1."
  )
  words <- typed(stated)
  scoped <- propose()
  scoped$source_quote <- stated
  scoped$scope <- "Panels cured in oven B"
  host_call_tool(
    f$store,
    f$key("t-01"),
    words,
    "propose_interpretation",
    scoped
  )
  host_settle_turn(f$store, f$key("t-01"), "done")
  # The contrast needs the scope, which only the earlier draft holds.
  host_call_tool(
    f$store,
    f$key("t-02"),
    words,
    "propose_normal_contrast",
    list(
      condition_low = 60,
      condition_high = 90,
      condition_units = "min",
      outcome = "hardness",
      units = "N",
      low05 = 10,
      low95 = 14,
      high05 = 12,
      high95 = 18,
      correlation = 0.5,
      sd_low = 2,
      sd_high = 3,
      threshold = 1,
      source_quote = stated,
      reason = "As stated."
    )
  )
  expect_identical(
    host_settle_turn(f$store, f$key("t-02"), "done")$state,
    "done"
  )
  d <- host_drafts(f$store, f$key("t-02"))[[1]]
  expect_identical(d$turn, "t-02")
  expect_identical(d$proposal$claim$scope, "Panels cured in oven B")
  expect_false(is.null(d$proposal$candidate))
  # The earlier call's receipts came with it.
  tools <- vapply(d$proposal$context$tool_results, `[[`, "", "tool")
  expect_true(all(
    c("propose_interpretation", "propose_normal_contrast") %in% tools
  ))
})
