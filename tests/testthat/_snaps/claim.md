# incomplete and revised claims preserve their meaning and attribution

    Code
      revise_claim(x, "B", "Correction", confidence = 0.9)
    Condition
      Error in `revise_claim()`:
      ! Supply unique named claim fields to revise; see `claim()`.

# changed fields invalidate content identifiers

    Code
      revise_claim(x, "B", "Correction")
    Condition
      Error in `check_seal()`:
      ! The suppose_claim record has changed outside its revision API.

