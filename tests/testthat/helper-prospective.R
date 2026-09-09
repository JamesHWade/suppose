prospective_fixture <- function(design = "observational", updated = FALSE) {
  clock <- new.env(parent = emptyenv())
  clock$now <- "2026-01-01T12:00:00Z"
  testthat::local_mocked_bindings(
    now_utc = function() clock$now,
    .env = parent.frame()
  )
  record <- suppose_example()
  update_id <- NULL
  if (updated) {
    o <- import_observations(
      data.frame(
        observation_id = paste0("training", 1:4),
        condition = rep(c("low", "high"), each = 2),
        outcome = c(49, 51, 57, 59),
        batch = paste0("training", 1:4),
        specimen = paste0("training", 1:4),
        observed_at = "2025-12-31T12:00:00Z"
      ),
      source = "training:fixture",
      protocol = "training",
      author = "Test analyst",
      units = "MPa",
      role = "update",
      exposure = "explored"
    )
    record <- record_observations(record, o, "Training outcomes")
    u <- update_prior(
      record$revisions[[3]]$candidate,
      o,
      c(low = 140, high = 160),
      independent = TRUE
    )
    record <- record_update(record, u, "Retrospective training update")
    update_id <- record$updates[[1]]$id
  }
  before <- record
  plan <- data.frame(
    observation_id = c("a1", "a2", "b1", "b2"),
    condition = rep(c("low", "high"), each = 2)
  )
  record <- commit_test(
    record,
    plan,
    c(low = 140, high = 160),
    "prospective:fixture",
    "collection-v1",
    "2026-01-03T12:00:00Z",
    "Test analyst",
    "Challenge the predicted difference",
    design,
    design_details = "Independent future batches; assignment as stated in protocol",
    independent = TRUE,
    outcomes_unseen = TRUE,
    update_id = update_id
  )
  clock$now <- "2026-01-02T12:00:00Z"
  list(
    record = record,
    before = before,
    c = record$commitments[[1]],
    plan = plan,
    clock = clock
  )
}

prospective_observations <- function(
  f,
  values = c(49, 51, 57, 59),
  rows = 1:4,
  time = "2026-01-02T10:00:00Z",
  protocol = "collection-v1",
  source = "prospective:fixture",
  role = "assessment",
  exposure = "unseen",
  scale = 1
) {
  import_observations(
    data.frame(
      observation_id = f$plan$observation_id[rows],
      condition = f$plan$condition[rows],
      outcome = values[rows],
      batch = paste0("batch", rows),
      specimen = paste0("specimen", rows),
      observed_at = rep(time, length.out = length(rows))
    ),
    source = source,
    protocol = protocol,
    author = "Test analyst",
    units = "MPa",
    role = role,
    exposure = exposure,
    scale = scale
  )
}
