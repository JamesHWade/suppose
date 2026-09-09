# table import rejects invented data and unusable column mappings

    Code
      measurement_table("id,x,y\na,1,2,3")
    Condition
      Error in `measurement_table()`:
      ! Each CSV row must have the same number of fields as the header.

---

    Code
      measurement_source_check(sub("77", "78", f$csv), list(list(role = "user", text = f$
        csv)))
    Condition
      Error in `measurement_source_check()`:
      ! Copy the user's CSV exactly; only line-break normalization is allowed.

---

    Code
      measurement_form_preview(f$record, v)
    Condition
      Error in `measurement_form_preview()`:
      ! Map distinct ID, outcome and predictor columns.

---

    Code
      measurement_form_preview(f$record, v)
    Condition
      Error in `import_observations()`:
      ! Updating requires known evidence exposure and cannot reuse observations already incorporated into the prior.

---

    Code
      measurement_form_preview(f$record, v)
    Condition
      Error in `numeric_column()`:
      ! Column "life" contains nonnumeric or infinite measurements.

---

    Code
      measurement_form_preview(f$record, v)
    Condition
      Error in `import_observations()`:
      ! Observation IDs must be unique within a source. Retain distinct IDs for actual replicate measurements.

