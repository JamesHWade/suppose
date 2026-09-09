# cancelled and stale tool requests cannot publish form changes

    Code
      tools[[5]]("Duration", "Add duration.", "Consider duration")
    Condition
      Error:
      ! The record changed during the assistant response. Retry against the new revision.

