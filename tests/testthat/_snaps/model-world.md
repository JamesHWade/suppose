# reviews require valid predictions and explicit human review

    Code
      record_model_implication(x, w, c, reason = "Reason", challenge = "Measure",
        author = "A")
    Condition
      Error in `record_model_implication()`:
      ! Review the model consequences and wording before retaining this implication.

---

    Code
      record_model_implication(x, w, c, reason = "Reason", challenge = "Measure",
        author = "A", reviewed = TRUE, scenario = 99)
    Condition
      Error in `check_number()`:
      ! `scenario` must be one finite number between 1 and 41.

---

    Code
      record_model_implication(x, w, c, reason = "Reason", challenge = "Measure",
        author = "A", reviewed = TRUE, comparison = w)
    Condition
      Error in `record_model_implication()`:
      ! A comparison requires distinct models with the same data, scenarios, response and units.

---

    Code
      validate_model_world(w)
    Condition
      Error in `check_seal()`:
      ! The suppose_model_world record has changed outside its revision API.

# tampered review summaries and broken model links are rejected

    Code
      validate_record(bad)
    Condition
      Error in `validate_model_worlds()`:
      ! The saved implication summary does not match its predictions.

---

    Code
      validate_record(bad)
    Condition
      Error in `validate_model_worlds()`:
      ! Invalid model implication reference or position.

# model-world app validates supplied starting snapshots

    Code
      suppose_app(model = list())
    Condition
      Error in `check_seal()`:
      ! Expected a valid <suppose_model_world> record.

---

    Code
      world_summary(suppose_model_example(), 1, NA_real_)
    Condition
      Error in `check_number()`:
      ! `threshold` must be one finite number between -Inf and Inf.

# the waiting-time example has positive, skewed outcomes

    Code
      plot_model_world(w, comparison = suppose_model_example())
    Condition
      Error in `plot_model_world()`:
      ! The comparison model needs the same fitting data, scenarios, response and units.
