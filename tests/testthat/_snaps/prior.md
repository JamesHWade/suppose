# incompatible summaries return measurable mismatch

    Code
      accept_revision(rec, "A", "Reviewed", "New data")
    Condition
      Error in `accept_revision()`:
      ! Resolve the quantile mismatch before accepting this candidate.

# units and unresolved judgments cannot be silently fitted

    Code
      fit_prior(ex$claim, js, 0, c(3, 3))
    Condition
      Error in `fit_prior()`:
      ! Clarify this judgment before fitting.
      i Contradictory
      i Supply increasing quantiles of an uncertain mean, with explicit probabilities.

