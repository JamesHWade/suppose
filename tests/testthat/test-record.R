test_that("acceptance and new revisions preserve earlier accepted records", {
  rec <- suppose_example(accept = TRUE)
  old <- rec$revisions[[3]]
  c <- revise_claim(
    old$claim,
    "B",
    "Population change",
    scope = "Formulation G"
  )
  rec2 <- record_revision(rec, c, reason = "New population")
  expect_identical(rec2$revisions[[3]], old)
  expect_null(rec2$revisions[[4]]$acceptance)
  expect_snapshot(error = TRUE, accept_revision(rec, "A", "Again", "More data"))
})
test_that("JSON round trips preserve data and stored computations", {
  rec <- suppose_example(accept = TRUE)
  path <- withr::local_tempfile(fileext = ".json")
  write_record(rec, path)
  restored <- read_record(path)
  expect_identical(json_data(restored), json_data(rec))
  expect_equal(
    restored$revisions[[3]]$prediction$draws,
    rec$revisions[[3]]$prediction$draws
  )
  err <- tryCatch(write_record(rec, path), error = identity)
  expect_s3_class(err, "suppose_exists")
  expect_identical(err$path, path)
  write_record(rec, path, overwrite = TRUE)
  expect_identical(read_record(path)$record_id, rec$record_id)
})
test_that("unknown schemas and broken references are rejected", {
  rec <- suppose_example()
  path <- withr::local_tempfile(fileext = ".json")
  rec$schema_version <- 99
  writeLines(json_data(rec), path)
  expect_snapshot(error = TRUE, read_record(path))
  rec$schema_version <- 1
  rec$revisions[[3]]$prediction <- rec$revisions[[2]]$prediction
  expect_snapshot(error = TRUE, validate_record(rec))
})
test_that("failed writes leave the old bundle intact and remove temporary files", {
  rec <- suppose_example()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "record.json")
  write_record(rec, path)
  before <- readLines(path)
  withr::local_options(suppose_test = TRUE)
  testthat::local_mocked_bindings(
    file_move = function(...) stop("simulated interrupted rename"),
    .package = "fs"
  )
  e <- tryCatch(write_record(rec, path, overwrite = TRUE), error = identity)
  expect_s3_class(e, "suppose_io")
  expect_identical(readLines(path), before)
  expect_identical(
    list.files(dir, all.files = TRUE, no.. = TRUE),
    "record.json"
  )
})

test_that("unresolved judgments round trip without becoming priors", {
  c <- claim("Temperature helps", "A")
  j <- judgment(
    140,
    kind = "qualitative",
    units = "MPa",
    author = "A",
    answer = "Probably a plateau"
  )
  rec <- elicitation_record(c) |>
    record_revision(c, reason = "Keep qualitative answer", judgments = list(j))
  path <- withr::local_tempfile(fileext = ".json")
  write_record(rec, path)
  out <- read_record(path)
  expect_identical(out$revisions[[2]]$judgments[[1]]$answer, j$answer)
  expect_null(out$revisions[[2]]$candidate)
  expect_s3_class(out$revisions[[2]]$claim, "suppose_claim")
  expect_snapshot(error = TRUE, predict_prior(c))
})

test_that("explicit absence remains editable after reopening", {
  c <- claim(
    "Temperature helps",
    "A",
    assumptions = character(),
    unresolved = character()
  )
  path <- withr::local_tempfile(fileext = ".json")
  write_record(elicitation_record(c), path)
  restored <- read_record(path)$revisions[[1]]$claim
  expect_identical(restored$assumptions, character())
  expect_identical(restored$unresolved, character())
  revised <- revise_claim(
    restored,
    "B",
    "More precise",
    wording = "Temperature changes mean strength"
  )
  expect_identical(revised$parent_id, c$id)
})
