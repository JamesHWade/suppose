test_that("editable plots retain exact analytic intervals and matching provenance", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("patchwork")
  skip_if_not_installed("ggdist")
  record <- suppose_example()
  entry <- record$revisions[[3]]
  withr::local_seed(2026)
  before <- .Random.seed
  p <- plot_prior(entry$candidate, entry$prediction, view = "intervals")
  expect_s3_class(p, "ggplot")
  expect_equal(
    p$data$lower,
    c(
      entry$prediction$summary$mean_difference$lower,
      entry$prediction$summary$batch_difference$lower
    )
  )
  expect_equal(
    p$data$upper,
    c(
      entry$prediction$summary$mean_difference$upper,
      entry$prediction$summary$batch_difference$upper
    )
  )
  expect_s3_class(plot_prior(entry$candidate), "patchwork")
  expect_identical(.Random.seed, before)
  expect_snapshot(
    error = TRUE,
    plot_prior(entry$candidate, record$revisions[[2]]$prediction)
  )
})

test_that("static and interactive views render including point masses", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("ggdist")
  skip_if_not_installed("patchwork")
  entry <- suppose_example()$revisions[[3]]
  for (view in c("overview", "means", "contrast", "intervals")) {
    p <- plot_prior(entry$candidate, view = view)
    path <- tempfile(fileext = ".png")
    ggplot2::ggsave(path, p, width = 7, height = 7, dpi = 100)
    expect_gt(file.info(path)$size, 1000)
    widget <- plot_prior(entry$candidate, view = view, interactive = TRUE)
    expect_s3_class(widget, "htmlwidget")
    built <- plotly::plotly_build(widget)
    expect_gt(length(built$x$data), 0)
  }
  visual <- inquiry_prior_visual(entry)
  visual$summary$mean_difference$sd <- 0
  visual$summary$batch_difference$sd <- 0
  expect_s3_class(
    ggplot2::ggplot_build(prior_ggplot(visual, "contrast")),
    "ggplot_built"
  )
})
