test_that('bundled brms worlds preserve coherent curves and predictive variation', {
  linear <- suppose_model_example('linear')
  curved <- suppose_model_example('curved')
  expect_s3_class(linear, 'suppose_model_world')
  expect_equal(linear$provenance$engine, 'brms')
  expect_equal(
    world_inventory(linear)$summary_definition$quantiles,
    c(0.05, 0.5, 0.95)
  )
  expect_equal(length(linear$expected), 400L)
  expect_equal(length(linear$scenarios), 41L)
  expect_match(linear$source, 'Synthetic teaching data')
  expect_equal(world_comparable(linear, curved), TRUE)
  expect_equal(linear$provenance$divergences, 0)
  expect_lt(linear$provenance$max_rhat, 1.01)
  expect_equal(curved$provenance$divergences, 0)
  expect_lt(curved$provenance$max_rhat, 1.01)
  e <- world_matrix(linear, 'expected')
  expect_lt(max(abs(t(apply(e, 1, diff, differences = 2)))), 1e-9)
  ce <- world_matrix(curved, 'expected')
  expect_lt(max(apply(ce, 1, function(r) max(diff(r, differences = 2)))), 0)
  j <- 16L
  y <- world_matrix(linear, 'future')[, j]
  expect_gt(stats::sd(y), stats::sd(e[, j]))
  s <- world_summary(linear, j, 60)
  expect_equal(s$future, unname(stats::quantile(y, c(0.05, 0.5, 0.95))))
  expect_equal(s$expected_above, sum(e[, j] > 60) / 400)
  expect_equal(s$future_above, sum(y > 60) / 400)
  expect_gt(world_summary(curved, 36)$impossible, 0.9)
  expect_gt(world_summary(linear, 36)$expected[2], 90)
  expect_lt(world_summary(curved, 36)$expected[2], 0)
})

test_that('reviewed implications preserve models, scenarios and independent claims', {
  w <- suppose_model_example()
  other <- suppose_model_example('curved')
  initial <- elicitation_record(claim('What does this model imply?', 'A'))
  c <- claim('The extrapolation needs checking.', 'B', scope = w$scope)
  x <- record_model_implication(
    initial,
    w,
    c,
    'challenge',
    reason = 'The observed range is narrower.',
    challenge = 'Measure at 60 degC.',
    author = 'B',
    reviewed = TRUE,
    scenario = 31,
    threshold = 55,
    realization = 9,
    comparison = other
  )
  expect_equal(x$revisions, initial$revisions)
  expect_length(x$model_worlds, 2)
  expect_length(x$model_implications, 1)
  expect_null(x$observations)
  expect_null(x$commitments)
  r <- x$model_implications[[1]]
  expect_equal(r$claim, c)
  expect_equal(r$scenario, 31)
  expect_equal(r$realization, 9)
  expect_equal(r$summary, world_summary(w, 31, 55))
  expect_equal(r$comparison_summary, world_summary(other, 31, 55))
  path <- withr::local_tempfile(fileext = '.json')
  write_record(x, path)
  expect_equal(read_record(path), x)
  encoded <- encode_inquiry_history(x, NULL, list())
  expect_equal(decode_inquiry_history(encoded)$record, x)
  changed <- record_model_implication(
    x,
    w,
    claim('Limit the scope.', 'C'),
    'qualify',
    reason = 'Restrict the application.',
    challenge = 'Check new batches.',
    author = 'C',
    reviewed = TRUE
  )
  expect_equal(changed$model_implications[[1]], r)
  expect_equal(changed$model_worlds, x$model_worlds)
  expect_length(changed$model_implications, 2)
  expect_equal(record_summary(x)$model_worlds[[1]]$id, other$id)
})

test_that('reviews require valid predictions and explicit human review', {
  w <- suppose_model_example()
  x <- elicitation_record(claim('Question', 'A'))
  c <- claim('Implication', 'A')
  expect_snapshot(
    error = TRUE,
    record_model_implication(
      x,
      w,
      c,
      reason = 'Reason',
      challenge = 'Measure',
      author = 'A'
    )
  )
  expect_snapshot(
    error = TRUE,
    record_model_implication(
      x,
      w,
      c,
      reason = 'Reason',
      challenge = 'Measure',
      author = 'A',
      reviewed = TRUE,
      scenario = 99
    )
  )
  expect_snapshot(
    error = TRUE,
    record_model_implication(
      x,
      w,
      c,
      reason = 'Reason',
      challenge = 'Measure',
      author = 'A',
      reviewed = TRUE,
      comparison = w
    )
  )
  w$future[[1]][1] <- 999
  expect_snapshot(error = TRUE, validate_model_world(w))
})

test_that('tampered review summaries and broken model links are rejected', {
  w <- suppose_model_example()
  x <- record_model_implication(
    elicitation_record(claim('Q', 'A')),
    w,
    claim('I', 'A'),
    reason = 'R',
    challenge = 'C',
    author = 'A',
    reviewed = TRUE
  )
  r <- unclass(x$model_implications[[1]])
  r$id <- r$type <- NULL
  r$summary$future_above <- 0.123456789
  bad <- x
  bad$model_implications[[1]] <- seal(r, 'suppose_model_implication')
  expect_snapshot(error = TRUE, validate_record(bad))
  bad <- x
  bad$model_worlds <- list()
  expect_snapshot(error = TRUE, validate_record(bad))
})

test_that('model-world app validates supplied starting snapshots', {
  skip_if_no_app()
  expect_snapshot(error = TRUE, suppose_app(model = list()))
  expect_snapshot(
    error = TRUE,
    world_summary(suppose_model_example(), 1, NA_real_)
  )
})


test_that('the waiting-time example has positive, skewed outcomes', {
  skip_if_not_installed('ggplot2')
  w <- suppose_model_example('waiting')
  expect_equal(w$family, 'lognormal')
  expect_equal(length(w$expected), 400)
  expect_gt(min(unlist(w$future)), 0)
  expect_equal(w$provenance$divergences, 0)
  expect_lt(w$provenance$max_rhat, 1.01)
  s <- world_summary(w, 41)
  expect_gt(s$future[3] - s$future[2], s$future[2] - s$future[1])
  expect_gt(s$change[2], 0)
  expect_gt(s$increase_fraction, 0.99)
  expect_equal(s$impossible, 0)
  expect_equal(world_comparable(w, suppose_model_example()), FALSE)
  expect_s3_class(plot_model_world(w), 'ggplot')
  expect_snapshot(
    error = TRUE,
    plot_model_world(w, comparison = suppose_model_example())
  )
})


test_that('a model can start an inquiry before any human interpretation', {
  w <- suppose_model_example()
  x <- model_world_inquiry(w)
  out <- record_model_world(x, w)
  expect_equal(out$revisions, x$revisions)
  expect_length(out$model_worlds, 1)
  expect_length(out$model_implications, 0)
  expect_null(out$observations)
  expect_null(out$revisions[[1]]$acceptance)
  expect_equal(record_model_world(out, w), out)
  path <- withr::local_tempfile()
  write_record(out, path)
  expect_equal(read_record(path), out)
})
