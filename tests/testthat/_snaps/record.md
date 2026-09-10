# acceptance and new revisions preserve earlier accepted records

    Code
      accept_revision(rec, "A", "Again", "More data")
    Condition
      Error in `accept_revision()`:
      ! This revision is already accepted; add a new revision to change it.

# unknown schemas and broken references are rejected

    Code
      read_record(path)
    Condition
      Error in `validate_record()`:
      ! Unsupported bundle schema; this version reads schemas 1 through 14.

---

    Code
      validate_record(rec)
    Condition
      Error in `validate_entry()`:
      ! Prediction references a different candidate.

# unresolved judgments round trip without becoming priors

    Code
      predict_prior(c)
    Condition
      Error in `check_seal()`:
      ! Expected a valid <suppose_prior> record.

