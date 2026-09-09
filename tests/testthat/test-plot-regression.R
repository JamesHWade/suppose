test_that("all regression plot views render including omitted-predictor residuals", {
  f <- regression_fixture(12)
  for (predictors in list("temperature", c("temperature", "duration"))) {
    spec <- regression_test_prior(f, predictors)
    r <- fit_regression(f$record, spec, TRUE, TRUE, draws = 200)
    views <- c(
      "prior",
      "prediction",
      "checks",
      "residuals",
      if (length(predictors) == 2L) "comparison"
    )
    for (view in views) {
      p <- plot_regression(r, view)
      path <- tempfile(fileext = ".png")
      ggplot2::ggsave(path, p, width = 8, height = 7, dpi = 70)
      expect_gt(file.info(path)$size, 1000)
    }
  }
})
