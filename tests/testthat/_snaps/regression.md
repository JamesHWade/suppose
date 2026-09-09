# fitting and retention require review and reject stale results

    Code
      fit_regression(f$record, spec)
    Condition
      Error in `fit_regression()`:
      ! Review the prior assumptions and confirm independent measurement units before fitting.

---

    Code
      record_regression(f$record, fit, "extended", "You", "Reason")
    Condition
      Error in `record_regression()`:
      ! Review predictive checks and model comparisons before retaining a choice.

---

    Code
      record_regression(x, fit, "extended", "You", "Reason", TRUE)
    Condition
      Error in `record_regression()`:
      ! The record changed. Refit against the current record before retaining.

---

    Code
      fit_regression(x, spec, TRUE, TRUE)
    Condition
      Error in `fit_regression()`:
      ! The record changed. Preview regression priors again.

# new-case predictions preserve transforms, separate uncertainty and flag extrapolation

    Code
      predict_regression(r, data.frame(temperature = 150))
    Condition
      Error in `predict_regression()`:
      ! Supply one to 500 cases with exactly the selected model's predictor columns.

# regression refuses assessment evidence, missing outcomes and repeated specimens

    Code
      regression_test_prior(assessment)
    Condition
      Error in `regression_dataset()`:
      ! Regression requires update-designated observations with declared exposure; assessment or prior-used outcomes cannot be fitted.

---

    Code
      regression_test_prior(missing)
    Condition
      Error in `regression_dataset()`:
      ! Use 6 to 500 complete outcome measurements; missing rows are not silently removed.

---

    Code
      fit_regression(repeated$record, spec, TRUE, TRUE)
    Condition
      Error in `fit_regression()`:
      ! Repeated specimens require a dependence model.

