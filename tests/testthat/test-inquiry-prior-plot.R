test_that("prior charts use recorded analytic summaries and preserve RNG state", {
  x <- suppose_example()
  # Use the package's existing fitted example, without running a model provider.
  p <- utils::tail(x$revisions, 1)[[1]]
  visual <- inquiry_prior_visual(p)
  expect_identical(visual$summary, p$prediction$summary)
  expect_identical(visual$means, p$candidate$means)
  expect_match(inquiry_prior_alt(visual), "central 90 percent", fixed = TRUE)
  withr::local_seed(17)
  before <- .Random.seed
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 700, height = 600)
  inquiry_prior_plot(visual)
  grDevices::dev.off()
  expect_identical(.Random.seed, before)
  expect_gt(file.info(file)$size, 1000)
  visual$summary$mean_difference$sd <- 0
  visual$summary$batch_difference$sd <- 0
  grDevices::png(file, width = 390, height = 480)
  inquiry_prior_plot(visual)
  grDevices::dev.off()
  expect_gt(file.info(file)$size, 1000)
  expect_null(inquiry_prior_visual(list()))
})
