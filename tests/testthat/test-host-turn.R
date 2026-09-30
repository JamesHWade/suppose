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
  expect_match(host_segment("../../etc"), "^etc-[0-9a-f]{12}$")
  expect_false(identical(host_segment("a b"), host_segment("a-b")))
  expect_true(host_before("t-01K6Z4N1", "t-01K6Z4R2"))
  expect_false(host_before("t-01K6Z4R2", "t-01K6Z4N1"))
  expect_false(host_before("t-1", "t-1"))
})
