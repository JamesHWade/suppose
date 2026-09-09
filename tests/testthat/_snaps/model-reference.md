# claims and retained priors have independent many-to-many references

    Code
      record_model_reference(x, a, models[1], "A", "Repeated")
    Condition
      Error in `record_model_reference()`:
      ! This claim already references this model.

---

    Code
      record_model_reference(x, a, "missing", "A", "Unresolvable")
    Condition
      Error in `validate_model_references()`:
      ! The referenced model is not retained in this record.

