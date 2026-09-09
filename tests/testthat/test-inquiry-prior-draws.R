test_that("realizations preserve joint draws and quantile dots represent analytic mass", {
  p <- utils::tail(suppose_example()$revisions, 1)[[1]]
  x <- inquiry_prior_visual(p)
  expect_identical(x$draws, p$prediction$draws)
  d <- prior_draw_values(x, 27)
  expect_equal(d[["mean_difference"]], d[["mean_high"]] - d[["mean_low"]])
  expect_equal(d[["batch_difference"]], d[["batch_high"]] - d[["batch_low"]])
  dots <- prior_draw_dots(x)
  expect_equal(as.integer(table(dots$quantity)), c(100L, 100L))
  expect_equal(
    mean(dots$above[dots$quantity == "Mean difference"]),
    x$summary$mean_difference$probability_above,
    tolerance = 0.005
  )
  x$summary$mean_difference$sd <- 0
  x$threshold <- x$summary$mean_difference$mean
  dots <- prior_draw_dots(x)
  expect_equal(sum(dots$above[dots$quantity == "Mean difference"]), 0)
  expect_identical(prior_draw_index(x, -9), 1L)
  expect_identical(prior_draw_index(x, Inf), 1L)
  expect_equal(prior_draw_index(x, 1e9), length(x$draws$mean_low))
})

test_that("draw plots have fixed limits and do not resample", {
  p <- utils::tail(suppose_example()$revisions, 1)[[1]]
  x <- inquiry_prior_visual(p)
  withr::local_seed(17)
  before <- .Random.seed
  for (view in c("pair", "dots")) {
    first <- prior_draw_plot(x, 1, view)
    next_draw <- prior_draw_plot(x, 2, view)
    expect_equal(first$coordinates$limits, next_draw$coordinates$limits)
    file <- tempfile(fileext = ".png")
    ggplot2::ggsave(file, first, width = 3.5, height = 3.8)
    expect_gt(file.info(file)$size, 1000)
  }
  expect_identical(.Random.seed, before)
  expect_match(prior_draw_summary(x, 2), "Realization 2 of")
  expect_match(prior_draw_probability(x), "Exact prior probabilities")
})

test_that("the explorer binds selected realizations independently for each panel", {
  server <- function(input, output, session) {
    visual <- shiny::reactiveVal(inquiry_prior_visual(utils::tail(
      suppose_example()$revisions,
      1
    )[[1]]))
    bind_inquiry_prior(output, "prior", visual, session)
    bind_inquiry_prior(output, "proposal", visual, session)
  }
  shiny::testServer(server, {
    session$setInputs(prior_draw_index = 12, proposal_draw_index = 3)
    expect_match(output$proposal_draw_summary, "Realization 3 of")
    expect_match(output$prior_draw_summary, "Realization 12 of")
    fixed_probability <- output$prior_draw_probability
    session$setInputs(prior_draw_index = 13)
    expect_match(output$prior_draw_summary, "Realization 13 of")
    expect_identical(output$prior_draw_probability, fixed_probability)
    sent <- list()
    session$sendInputMessage <- function(inputId, message) {
      sent[[inputId]] <<- message
    }
    session$setInputs(prior_draw_previous = 1)
    expect_equal(sent$prior_draw_index$value, "12")
    session$setInputs(prior_draw_next = 1)
    expect_equal(sent$prior_draw_index$value, "14")
    expect_match(output$proposal_draw_summary, "Realization 3 of")
  })
})
