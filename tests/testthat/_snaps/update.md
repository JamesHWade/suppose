# updating requires explicit evidence roles and independence

    Code
      update_prior(f$prior, f$obs, f$map)
    Condition
      Error in `update_prior()`:
      ! Confirm independent measurement units explicitly; paired or clustered measurements need a different likelihood.

---

    Code
      update_prior(f$prior, f$obs, c(other = 140, high = 160), independent = TRUE)
    Condition
      Error in `update_prior()`:
      ! An observation condition is absent from the explicit mapping.

---

    Code
      update_prior(f$prior, list(f$obs, f$obs), f$map, independent = TRUE)
    Condition
      Error in `update_prior()`:
      ! The same source/observation ID was supplied more than once.

---

    Code
      update_prior(f$prior, explored, f$map, independent = TRUE)
    Condition
      Error in `update_prior()`:
      ! Use only observations designated for updating; unknown exposure or evidence already used in the prior cannot be reused.

# retained updates preserve the original record and survive JSON

    Code
      record_update(record, fit, "")
    Condition
      Error in `check_text()`:
      ! `reason` must be one nonempty string.

