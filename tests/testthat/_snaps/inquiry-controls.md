# switching Deputy models preserves conversation and record

    Code
      state$switch_agent(factory("demo/third"))
    Condition
      Error in `busy()`:
      ! Finish or cancel the response before changing the record.

# a catalog failure leaves the current conversation usable

    Code
      session$setInputs(open_models = 1)
    Condition
      Warning in `catalog_task$invoke()`:
      ERROR: An error occurred when invoking the ExtendedTask.
      Caused by error in `catalog_request()`:
      ! Offline test

