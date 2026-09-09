# partial cohorts, exact corrections and later revisions preserve frozen tests

    Code
      assess_regression_test(f$record, f$id, "Reviewer", "Duplicate", TRUE)
    Condition
      Error in `assess_regression_test()`:
      ! This assessment is already retained for the same evidence and outcome.

# freezing rejects reused outcomes, stale previews and unreviewed declarations

    Code
      commit_regression_test(f$before, f$plan, "Reviewer", "No confirmations")
    Condition
      Error in `commit_regression_test()`:
      ! Confirm independent units and unexamined designated outcomes before freezing.

---

    Code
      commit_regression_test(f$record, f$plan, "Reviewer", "Stale", TRUE, TRUE)
    Condition
      Error in `commit_regression_test()`:
      ! The record changed. Preview the regression test again.

---

    Code
      commit_regression_test(f$before, f$plan, "Reviewer", "Expired", TRUE, TRUE)
    Condition
      Error in `commit_regression_test()`:
      ! The deadline has passed. Prepare a new future test.

---

    Code
      plan_regression_test(f$before, f$design$regression_id, data,
      "synthetic:regression", "p", "2026-01-03T12:00:00Z", "target", design_details = "independent")
    Condition
      Error in `plan_regression_test()`:
      ! Planned IDs are already present in this source. Existing outcomes cannot become a prospective test.

---

    Code
      regression_research_attach(f)
    Condition
      Error in `record_regression_test_data()`:
      ! These IDs are already attached. Select the active attachment to correct them explicitly.

---

    Code
      regression_research_attach(f, f$data[1:2, ], f$record$regression_test_data[[1]]$
        id)
    Condition
      Error in `record_regression_test_data()`:
      ! Correct one active attachment using exactly its original measurement IDs.

# a linked commitment must match an accepted planning choice

    Code
      do.call(plan_regression_test, args)
    Condition
      Error:
      ! Choose a nondeclined research plan for this exact regression.

---

    Code
      do.call(plan_regression_test, args)
    Condition
      Error:
      ! Future settings and replicate count must match the reviewed plan's choice. Revise the planning review or leave plan_id unset for a separate test.
