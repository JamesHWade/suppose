# predictors match outcome IDs regardless of upload order

    Code
      regression_predictors(f$record, f$record$observations[[1]]$id, bad, c(
        temperature = "degC", duration = "minutes"), "source", "Analyst")
    Condition
      Error in `regression_predictors()`:
      ! Predictor IDs must match every measurement in the selected evidence exactly once.

# missing predictor values and ambiguous units are not silently repaired

    Code
      regression_predictors(f$record, f$record$observations[[1]]$id, bad, c(
        temperature = "degC", duration = "minutes"), "source", "Analyst")
    Condition
      Error in `regression_predictors()`:
      ! Predictor "duration" must contain finite numbers and vary across measurements.

---

    Code
      regression_predictors(f$record, f$record$observations[[1]]$id, f$data, c("degC",
        "minutes"), "source", "Analyst")
    Condition
      Error in `regression_predictors()`:
      ! Name one unit for each predictor column.

