test_that("sensitivity plots retain the selected quantities and baseline", {
  skip_if_not_installed("ggplot2")
  f <- sensitivity_fixture()
  s <- sensitivity_analysis(f$record, f$update$id)
  for (quantity in c("estimate", "probability")) {
    p <- plot_sensitivity(s, quantity)
    expect_s3_class(p, "ggplot")
    expect_equal(nrow(p$data), 6)
    expect_equal(sort(unique(p$data$power)), s$powers)
    path <- tempfile(fileext = ".png")
    ggplot2::ggsave(path, p, width = 5, height = 5, dpi = 96)
    expect_gt(file.info(path)$size, 1000)
  }
  restricted <- sensitivity_analysis(
    f$record,
    f$update$id,
    quantities = "assessment"
  )
  expect_snapshot(error = TRUE, plot_sensitivity(restricted, "estimate"))
})
