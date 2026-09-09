# invalid probabilities have actionable errors

    Code
      judgment(140, c(45, 55), c(0, 1), units = "MPa", author = "A", answer = "Answer")
    Condition
      Error in `judgment()`:
      ! Use distinct `probabilities` strictly between 0 and 1, one per value.

