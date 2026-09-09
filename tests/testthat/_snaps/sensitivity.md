# retention round trips exact references and rejects stale or changed records

    Code
      record_sensitivity(x, s, "Stale")
    Condition
      Error in `record_sensitivity()`:
      ! The record changed. Recompute sensitivity before retaining it.

---

    Code
      validate_record(tampered)
    Condition
      Error in `check_seal()`:
      ! The suppose_sensitivity_entry record has changed outside its revision API.

---

    Code
      validate_record(tampered)
    Condition
      Error in `sensitivity_update()`:
      ! Select an exact retained update from this record.

# unsupported perturbations and output choices fail explicitly

    Code
      sensitivity_analysis(f$record, "missing")
    Condition
      Error in `sensitivity_update()`:
      ! Select an exact retained update from this record.

---

    Code
      sensitivity_analysis(f$record, f$update$id, powers = c(0, 1))
    Condition
      Error in `sensitivity_analysis()`:
      ! Supply at most 21 finite powers between 0.1 and 10.

---

    Code
      sensitivity_analysis(f$record, f$update$id, components = "shape")
    Condition
      Error in `sensitivity_choices()`:
      ! Choose supported `components`: prior, likelihood.

---

    Code
      sensitivity_analysis(f$record, f$update$id, quantities = "causal_effect")
    Condition
      Error in `sensitivity_choices()`:
      ! Choose supported `quantities`: estimate, probability, assessment.

---

    Code
      sensitivity_analysis(f$record, f$update$id, probability_change = 0)
    Condition
      Error in `sensitivity_analysis()`:
      ! Choose positive changes worth reviewing for both quantities.

