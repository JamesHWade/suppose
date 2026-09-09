test_that("claims and retained priors have independent many-to-many references", {
  x <- suppose_example(accept = TRUE)
  models <- vapply(x$revisions[2:3], function(e) e$candidate$id, character(1))
  a <- claim("The benefit exceeds the cost", "A", units = "MPa")
  b <- claim("The benefit is insufficient", "B")
  before <- x$revisions
  x <- record_model_reference(
    x,
    a,
    models[1],
    "A",
    "Requires an explicit cost conversion"
  )
  x <- record_model_reference(
    x,
    a,
    models[2],
    "A",
    "Alternative dependence assumption"
  )
  x <- record_model_reference(
    x,
    b,
    models[1],
    "B",
    "A different usefulness threshold"
  )
  expect_length(x$model_references, 3)
  expect_identical(x$revisions, before)
  path <- withr::local_tempfile(fileext = ".json")
  write_record(x, path)
  expect_identical(json_data(read_record(path)), json_data(x))
  expect_snapshot(
    error = TRUE,
    record_model_reference(x, a, models[1], "A", "Repeated")
  )
  expect_snapshot(
    error = TRUE,
    record_model_reference(x, a, "missing", "A", "Unresolvable")
  )
})
