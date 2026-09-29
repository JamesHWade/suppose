test_that("plots show the original prediction and only eligible observed statistics", {
  skip_if_not_installed("ggplot2")
  f <- prospective_fixture()
  x <- record_observations(f$record, prospective_observations(f), "Outcomes")
  a <- assess_test(x, f$c$id, "Reviewer", "Compare", TRUE)$assessments[[1]]
  p <- plot_test(f$c, a)
  expect_s3_class(p, "ggplot")
  expect_equal(p$data$lower[1], f$c$prediction$lower)
  expect_equal(p$data$value[2], 8)
  pending <- assess_test(
    f$record,
    f$c$id,
    "Reviewer",
    "Check completeness"
  )$assessments[[1]]
  expect_equal(nrow(plot_test(f$c, pending)$data), 1)
  path <- tempfile(fileext = ".png")
  ggplot2::ggsave(path, p, width = 7, height = 3, dpi = 100)
  expect_gt(file.info(path)$size, 1000)
})
