# conversion preserves originals, missingness, and repeated measurements

    Code
      print(d)
    Message
      
      -- Measured observations --
      
      3 rows from lab:run-1; 1 missing outcomes.
      Use: exploration. Prior exposure: unknown. Units: V.
      2 rows have identical measurement fields; retained for review.

# CSV import preserves numeric-looking identities and rejects bad outcomes

    Code
      measurement_import(path, role = "exploration", exposure = "explored")
    Condition
      Error in `import_observations()`:
      ! CSV outcomes must be numeric or blank for missing values.

# previous exposure blocks independent assessment and double updating

    Code
      measurement_import(role = "assessment", exposure = "explored")
    Condition
      Error in `import_observations()`:
      ! Assessment requires an explicit declaration of unseen outcomes. Use exploration for previously examined or uncertain evidence.

---

    Code
      measurement_import(role = "update", exposure = "prior")
    Condition
      Error in `import_observations()`:
      ! Updating requires known evidence exposure and cannot reuse observations already incorporated into the prior.

---

    Code
      measurement_import(role = "update", exposure = "unknown")
    Condition
      Error in `import_observations()`:
      ! Updating requires known evidence exposure and cannot reuse observations already incorporated into the prior.

# observations retain their revision and survive conversation and acceptance

    Code
      record_observations(changed, d, "Another copy")
    Condition
      Error in `validate_evidence()`:
      ! These source/observation IDs are already attached. Reusing them under a new role or conversion would count the same information twice.

# conversion and claim reference cannot be silently changed

    Code
      record_observations(record, d, "Unit mismatch")
    Condition
      Error in `record_observations()`:
      ! Converted observation units must match the claim units exactly. Specify the conversion explicitly before attaching.

---

    Code
      record_observations(elicitation_record(claim("Another", "Ada")), corrupt,
      "Tampered")
    Condition
      Error in `validate_observations()`:
      ! Observation values and declared conversion disagree.

---

    Code
      validate_record(record)
    Condition
      Error in `validate_evidence()`:
      ! Observations reference a different claim or candidate.

# malformed identities, times and conversions fail before attachment

    Code
      measurement_import(data, role = "exploration", exposure = "unknown")
    Condition
      Error in `import_observations()`:
      ! Observation IDs must be unique within a source. Retain distinct IDs for actual replicate measurements.

---

    Code
      measurement_import(data, role = "exploration", exposure = "unknown")
    Condition
      Error in `import_observations()`:
      ! Observation times must be valid UTC timestamps such as 2026-09-08T12:00:00Z, or unknown when not documented.

---

    Code
      measurement_import(role = "exploration", exposure = "unknown", scale = 0)
    Condition
      Error in `import_observations()`:
      ! Conversion scale cannot be zero.

---

    Code
      measurement_import(role = "exploration", exposure = "unknown", scale = .Machine$
        double.xmax)
    Condition
      Error in `import_observations()`:
      ! Conversion produced a non-finite outcome.

---

    Code
      measurement_import(suppose_example()$revisions[[2]]$prediction, role = "exploration",
      exposure = "unknown")
    Condition
      Error in `import_observations()`:
      ! Supply 1 to 100000 rows with exactly: observation_id, condition, outcome, batch, specimen, observed_at.

