test_that("the first-session example exposes an assumption and a challenge", {
  x <- suppose_example(accept = TRUE)
  expect_length(x$revisions, 3)
  a <- x$revisions[[2]]$prediction$summary$mean_difference
  b <- x$revisions[[3]]$prediction$summary$mean_difference
  expect_equal(a$mean, b$mean)
  expect_gt(b$probability_above, a$probability_above)
  expect_match(x$revisions[[3]]$acceptance$challenge, "randomized")
  expect_snapshot(print(x))
  expect_snapshot(print(x$revisions[[3]]$prediction))
})
