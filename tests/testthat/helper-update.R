update_fixture <- function(
  values = c(49, 50, 51, 59, 60, 61),
  conditions = rep(c("low", "high"), each = 3)
) {
  record <- suppose_example()
  e <- record$revisions[[3]]
  n <- length(values)
  obs <- import_observations(
    data.frame(
      observation_id = paste0("obs", seq_len(n)),
      condition = conditions,
      outcome = values,
      batch = paste0("batch", seq_len(n)),
      specimen = paste0("specimen", seq_len(n)),
      observed_at = rep("2026-09-08T12:00:00Z", n)
    ),
    source = "test:independent",
    protocol = "Independent units; known SD3",
    author = "Test analyst",
    units = "MPa",
    role = "update",
    exposure = "explored"
  )
  list(
    record = record,
    prior = e$candidate,
    obs = obs,
    map = c(low = 140, high = 160)
  )
}
