test_that('the walkthrough retains exact scenario reviews without changing the main claim', {
  w <- suppose_model_example()
  original <- elicitation_record(claim('My existing inquiry', 'A'))
  current <- shiny::reactiveVal(original)
  shiny::testServer(
    model_world_server,
    args = list(current = current, guard = function() NULL, model = w),
    {
      session$setInputs(
        model = w$id,
        mounted = 1,
        scenario = 70,
        threshold = 60,
        realization = 3,
        comparison = 'none'
      )
      session$setInputs(
        claim = 'This extrapolation needs a check.',
        position = 'challenge',
        reason = 'Outside the fitting range.',
        challenge = 'Measure at 60 degC.',
        author = 'B'
      )
      session$setInputs(reviewed = TRUE)
      session$setInputs(retain = 1)
      expect_length(current()$model_implications, 1)
      expect_equal(current()$revisions, original$revisions)
      r <- current()$model_implications[[1]]
      expect_equal(r$scenario, 36)
      expect_equal(r$realization, 3)
      expect_match(status(), 'retained')
      session$setInputs(retain = 2)
      expect_length(current()$model_implications, 1)
      expect_match(status(), 'just retained')
    }
  )
})

test_that('a model review can start a fresh inquiry and cannot bypass the guard', {
  w <- suppose_model_example()
  current <- shiny::reactiveVal(NULL)
  blocked <- FALSE
  shiny::testServer(
    model_world_server,
    args = list(
      current = current,
      guard = function() {
        if (blocked) abort_suppose('Pending review must be resolved.')
      },
      model = w
    ),
    {
      session$setInputs(
        model = w$id,
        mounted = 1,
        scenario = 30,
        threshold = 60,
        realization = 1,
        comparison = 'none',
        claim = 'A conditional prediction.',
        position = 'qualify',
        reason = 'Bound the scope.',
        challenge = 'Independent measurements.',
        author = 'B'
      )
      session$setInputs(reviewed = TRUE)
      session$setInputs(retain = 1)
      expect_s3_class(current(), 'suppose_record')
      expect_length(current()$model_implications, 1)
      before <- current()
      blocked <<- TRUE
      session$setInputs(
        claim = 'Another implication.',
        reviewed = TRUE,
        retain = 2
      )
      expect_equal(current(), before)
      expect_match(status(), 'Pending review')
    }
  )
})
