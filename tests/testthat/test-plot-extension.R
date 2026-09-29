test_that("extension plots distinguish three alternatives under aligned scenarios", {
  skip_if_not_installed("ggplot2")
  c <- compare_extension(suppose_example(), "Duration", "minutes", 60, 10)
  for (quantity in c("outcome", "mean")) {
    p <- plot_extension(c, quantity)
    expect_s3_class(p, "ggplot")
    expect_setequal(unique(p$data$model), c("original", "unscaled", "scaled"))
    expect_equal(nrow(p$data), 45)
    file <- tempfile(fileext = ".png")
    ggplot2::ggsave(file, p, width = 5, height = 6, dpi = 120)
    expect_gt(file.info(file)$size, 1000)
  }
})
