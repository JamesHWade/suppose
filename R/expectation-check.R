#' Inspect expectations under an explicit straight-line projection
#'
#' Reuses [compare_extension()] with no added effect to inspect a jointly normal
#' two-anchor prior between and beyond its anchors. Straight-line means and the
#' measurement-noise rule are additional assumptions, never inferred from two
#' elicited points. Unfitted judgments remain visible; range and qualitative
#' answers are not converted to probability statements or adequacy scores.
#' @param x A record containing a current normal prior.
#' @param linear Confirm the additional projection assumption with `TRUE`.
#' @param conditions Numeric conditions to inspect; by default includes two
#'   anchors, midpoint, and points 25 percent beyond each anchor.
#' @return A list of prediction rows, attributed expectations and assumptions.
#' @export
check_expectations <- function(x, linear = FALSE, conditions = NULL) {
  if (!identical(linear, TRUE)) {
    abort_suppose(
      "Explicitly choose linear = TRUE to inspect the additional straight-line projection assumption.",
      "assumption"
    )
  }
  comparison <- compare_extension(
    x,
    predictor = "No added effect",
    effect_mean = 0,
    effect_sd = 0,
    predictor_values = 0,
    conditions = conditions
  )
  rows <- Filter(function(r) r$model == "original", comparison$rows)
  e <- utils::tail(x$revisions, 1)[[1]]
  p <- e$candidate
  sigma <- outer(p$mean_sd, p$mean_sd) *
    matrix(c(1, p$correlation, p$correlation, 1), 2)
  weights <- function(condition) {
    t <- (condition - p$conditions[1]) / diff(p$conditions)
    c(1 - t, t)
  }
  expectations <- lapply(e$judgments, function(j) {
    result <- list(
      judgment = j,
      implied = NULL,
      difference = NULL,
      explanation = "This answer remains qualitative or unresolved; no numerical mismatch is assigned."
    )
    if (
      !identical(j$units, p$claim$units) ||
        !identical(j$condition_units, p$condition_units)
    ) {
      result$explanation <- "Units differ from the model. No conversion or numerical comparison was made."
      return(result)
    }
    w <- weights(j$condition)
    if (j$quantity == "contrast") {
      if (is.null(j$reference_condition)) {
        result$explanation <- "A contrast requires an identified reference condition; no comparison was made."
        return(result)
      }
      w <- w - weights(j$reference_condition)
    }
    mu <- sum(w * p$means)
    variance <- max(0, drop(w %*% sigma %*% w))
    if (
      j$kind == "quantile" &&
        !length(j$issues) &&
        j$quantity %in% c("mean", "contrast")
    ) {
      result$implied <- mu + stats::qnorm(j$probabilities) * sqrt(variance)
      result$difference <- result$implied - j$values
      result$explanation <- "Implied quantiles minus stated quantiles, in outcome units. Away from anchors this depends on the additional straight-line assumption."
    } else if (j$quantity == "shape") {
      result$explanation <- "The projected mean is a straight line in every draw. It cannot represent an interior peak, trough or plateau after a rising segment. A stated shape may therefore require a different model."
    } else if (j$kind == "range") {
      result$explanation <- "A plausible range has no probability level. Compare it with the displayed intervals without treating it as an elicited probability interval."
    } else if (
      j$kind == "comparison" &&
        j$quantity == "mean" &&
        !is.null(j$reference_condition)
    ) {
      d <- weights(j$condition) - weights(j$reference_condition)
      dm <- sum(d * p$means)
      ds <- sqrt(max(0, drop(d %*% sigma %*% d)))
      prob <- if (ds == 0) as.numeric(dm > 0) else stats::pnorm(dm / ds)
      result$implied <- prob
      result$explanation <- sprintf(
        "Under the projection, P(mean at %g > mean at %g) = %.3f. Your wording was not assigned a probability; this is a model consequence, not empirical evidence.",
        j$condition,
        j$reference_condition,
        prob
      )
    }
    if (!all(is.finite(c(result$implied, result$difference)))) {
      abort_suppose(
        "Expectation comparison exceeds the numerical range.",
        "computation"
      )
    }
    result
  })
  list(
    prior_id = p$id,
    rows = rows,
    expectations = expectations,
    units = p$claim$units,
    condition_units = p$condition_units,
    assumptions = c(
      "The original two anchors do not determine behavior elsewhere. This view adds a straight-line mean interpolation/extrapolation assumption.",
      "Known batch noise interpolates in variance between anchors and stays at the nearest anchor value outside.",
      "Mean intervals describe uncertainty in the population mean. Future-batch intervals additionally include known batch variation.",
      "Matching an expectation is not evidence that the model describes the external system."
    )
  )
}

expectation_check_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tags$details(
    shiny::tags$summary("Inspect expectations beyond the anchors"),
    shiny::tags$p(
      "The two elicited conditions do not determine the response shape between or beyond them."
    ),
    shiny::checkboxInput(
      ns("linear"),
      "Inspect a straight-line mean projection with the stated batch-noise rule",
      FALSE
    ),
    shiny::uiOutput(ns("comparison"))
  )
}

expectation_check_server <- function(id, current) {
  shiny::moduleServer(id, function(input, output, session) {
    output$comparison <- shiny::renderUI({
      if (!isTRUE(input$linear)) {
        return(NULL)
      }
      tryCatch(
        {
          x <- check_expectations(current(), linear = TRUE)
          shiny::tagList(
            shiny::tags$ul(lapply(x$assumptions, shiny::tags$li)),
            shiny::tags$div(
              style = "overflow-x:auto",
              tabindex = "0",
              role = "region",
              `aria-label` = "Projected means and future batches; scroll horizontally for all columns",
              shiny::tags$table(
                class = "table table-sm",
                shiny::tags$caption(paste(
                  "Central 90% intervals in",
                  x$units,
                  "; conditions in",
                  x$condition_units
                )),
                shiny::tags$thead(shiny::tags$tr(lapply(
                  c(
                    "Condition",
                    "Basis",
                    "Mean",
                    "Mean interval",
                    "Future batch interval"
                  ),
                  shiny::tags$th
                ))),
                shiny::tags$tbody(lapply(x$rows, function(r) {
                  shiny::tags$tr(
                    shiny::tags$td(r$condition),
                    shiny::tags$td(r$condition_basis),
                    shiny::tags$td(sprintf("%.3g", r$mean)),
                    shiny::tags$td(sprintf(
                      "%.3g to %.3g",
                      r$mean_lower,
                      r$mean_upper
                    )),
                    shiny::tags$td(sprintf(
                      "%.3g to %.3g",
                      r$outcome_lower,
                      r$outcome_upper
                    ))
                  )
                }))
              )
            ),
            shiny::tags$h4("Your expectations and model consequences"),
            lapply(x$expectations, function(e) {
              shiny::tagList(
                shiny::tags$blockquote(e$judgment$answer),
                shiny::tags$p(e$explanation),
                if (!is.null(e$difference)) {
                  shiny::tags$p(paste(
                    "Implied minus stated:",
                    paste(signif(e$difference, 3), collapse = ", "),
                    x$units
                  ))
                }
              )
            })
          )
        },
        error = function(e) shiny::tags$p(role = "status", conditionMessage(e))
      )
    })
  })
}
