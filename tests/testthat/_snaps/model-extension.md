# reviewed alternatives preserve original records and round trip

    Code
      record_extension(x, c, "Reviewer", "Stale", reviewed = TRUE)
    Condition
      Error in `record_extension()`:
      ! The record changed. Preview the extension again before retaining it.

---

    Code
      record_extension(f$record, c, "Reviewer", "Not yet reviewed")
    Condition
      Error in `record_extension()`:
      ! Review the new assumptions and predictions before retaining the extension.

# unsupported and failed extension calculations do not create a model

    Code
      compare_extension(x, "Duration", scale = 0)
    Condition
      Error in `compare_extension()`:
      ! Choose a positive meaningful predictor change.

---

    Code
      compare_extension(x, "Duration", effect_sd = -1)
    Condition
      Error in `check_number()`:
      ! `effect_sd` must be one finite number between 0 and Inf.

---

    Code
      compare_extension(x, "Duration", plausible_lower = 10, plausible_upper = 0)
    Condition
      Error in `compare_extension()`:
      ! The lower plausible bound must be below the upper bound.

---

    Code
      compare_extension(x, "Duration", effect_sd = 1e+308)
    Condition
      Error in `compare_extension()`:
      ! This comparison exceeds the numerical range. Review the units and scales; no extension was retained.

---

    Code
      compare_extension(elicitation_record(claim("Question", "You")), "Duration")
    Condition
      Error in `compare_extension()`:
      ! Retain a normal prior before comparing an extension.

