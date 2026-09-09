# missing outcomes wait until the horizon and preserve earlier assessments

    Code
      assess_test(out, f$c$id, "Reviewer", "Repeated click", TRUE)
    Condition
      Error in `assess_test()`:
      ! This assessment is already retained for the same evidence and outcome. Add later outcomes or wait for the deadline before reassessing.

# plan revisions retain ancestry and cannot reuse already attached outcomes

    Code
      commit_test(x, f$plan, c(low = 140, high = 160), f$c$source, f$c$protocol, f$c$
        horizon, "Analyst", "Try to recommit", design_details = "Same protocol",
      independent = TRUE, outcomes_unseen = TRUE)
    Condition
      Error in `commit_test()`:
      ! Planned measurement IDs are already present in this record. Use new outcomes; existing evidence cannot become a prospective test.

# commitment review requires an unexpired deadline and explicit declarations

    Code
      commit_test(f$before, f$plan, c(low = 140, high = 160), f$c$source, f$c$
      protocol, f$c$horizon, "Analyst", "A test", design_details = "Protocol")
    Condition
      Error in `commit_test()`:
      ! Explicitly confirm independent units and unexamined designated outcomes before committing.

---

    Code
      commit_test(f$before, f$plan, c(low = 140, high = 160), f$c$source, f$c$
      protocol, "2026-01-01T12:00:00Z", "Analyst", "A test", design_details = "Protocol",
      independent = TRUE, outcomes_unseen = TRUE)
    Condition
      Error in `commit_test()`:
      ! The collection deadline must be in the future when the commitment is frozen.

---

    Code
      test_time("2026-02-30T12:00:00Z", "deadline")
    Condition
      Error in `test_time()`:
      ! `deadline` must be a valid UTC timestamp, such as 2026-09-08T12:00:00Z.

---

    Code
      test_plan(transform(f$plan, observation_id = "same"), c(low = 140, high = 160),
      c(140, 160))
    Condition
      Error in `test_plan()`:
      ! Planned measurement IDs must be unique.

---

    Code
      test_plan(f$plan, c(low = 0, high = 1), c(140, 160))
    Condition
      Error in `test_plan()`:
      ! Map two distinct labels to the prior's exact conditions.

# saved commitment tampering is detected

    Code
      validate_record(x)
    Condition
      Error in `check_seal()`:
      ! The suppose_test_commitment record has changed outside its revision API.

---

    Code
      validate_record(x)
    Condition
      Error in `validate_tests()`:
      ! Commitment references disagree with the retained scientific basis.

