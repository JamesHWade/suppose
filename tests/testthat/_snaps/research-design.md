# reviews reject stale, missing, ineligible and malformed inputs

    Code
      research_design_test_preview(f, purpose = "decide")
    Condition
      Error in `check_text()`:
      ! `preference` must be one nonempty string.

---

    Code
      record_research_design(f$record, d, "low", "Reviewer", "Reason")
    Condition
      Error in `record_research_design()`:
      ! Review the design assumptions and feasibility before retaining a choice.

---

    Code
      record_research_design(f$record, d, "unavailable", "Reviewer", "Reason", TRUE)
    Condition
      Error in `record_research_design()`:
      ! Choose an eligible candidate or none.

---

    Code
      record_research_design(retained, d, "low", "Reviewer", "Reason", TRUE)
    Condition
      Error in `record_research_design()`:
      ! The record changed. Refresh the design preview before retaining it.

---

    Code
      research_design_test_preview(f)
    Condition
      Error in `alloptr::bed_normal_contrast()`:
      ! Supply one to 100 independent replicates for each candidate row.

---

    Code
      research_design_test_preview(f)
    Condition
      Error in `predict_regression()`:
      ! New predictor values must be finite numbers in the original units.

