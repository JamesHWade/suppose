# Rebuild reviewable visualization examples without contacting a model provider.
pkgload::load_all(quiet = TRUE)
out <- file.path("artifacts", "visualizations")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
entry <- suppose_example()$revisions[[3]]
for (view in c("overview", "means", "contrast", "intervals")) {
  p <- plot_prior(entry$candidate, entry$prediction, view)
  for (format in c("png", "svg", "pdf")) {
    ggplot2::ggsave(
      file.path(out, paste0(view, ".", format)),
      p,
      width = 8,
      height = if (view == "overview") 8 else 4.5,
      dpi = 160
    )
  }
}
widget <- plot_prior(entry$candidate, view = "contrast", interactive = TRUE)
htmlwidgets::saveWidget(
  widget,
  file.path(out, "contrast.html"),
  selfcontained = TRUE
)
s <- entry$prediction$summary
summary <- data.frame(
  Quantity = c("Mean difference", "Future measurements"),
  Mean = c(s$mean_difference$mean, s$batch_difference$mean),
  Lower = c(s$mean_difference$lower, s$batch_difference$lower),
  Upper = c(s$mean_difference$upper, s$batch_difference$upper)
)
table <- gt::gt(summary) |>
  gt::fmt_number(columns = c(Mean, Lower, Upper), decimals = 2) |>
  gt::tab_header(
    title = "Prior consequences",
    subtitle = "Invented judgments; central 90% intervals in MPa"
  )
gt::gtsave(table, file.path(out, "summary.html"))
map <- leaflet::leaflet(datasets::quakes) |>
  leaflet::addTiles() |>
  leaflet::addCircleMarkers(
    lng = ~long,
    lat = ~lat,
    radius = ~mag,
    popup = ~ paste("Magnitude", mag, "— depth", depth, "km"),
    stroke = FALSE,
    fillOpacity = 0.4
  )
htmlwidgets::saveWidget(
  map,
  file.path(out, "earthquakes.html"),
  selfcontained = TRUE
)
packages <- c(
  "ggplot2",
  "patchwork",
  "ggdist",
  "plotly",
  "leaflet",
  "gt",
  "htmlwidgets",
  "svglite"
)
write.csv(
  data.frame(
    package = packages,
    version = vapply(
      packages,
      function(p) as.character(utils::packageVersion(p)),
      character(1)
    )
  ),
  file.path(out, "versions.csv"),
  row.names = FALSE
)
writeLines(
  c(
    '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Suppose visualization examples</title>',
    '<style>body{font:17px system-ui;max-width:1000px;margin:40px auto;padding:0 20px;background:#faf9f5;color:#243d34}img,iframe{width:100%;border:0}iframe{height:520px}a{color:#245747}</style>',
    '<h1>Suppose visualization examples</h1><p>The strength example uses invented prior judgments. The earthquake map uses the built-in R quakes dataset.</p>',
    '<h2>ggplot2 and patchwork</h2><img src="overview.png" alt="Prior means and their contrasting implications; future measurements have wider uncertainty than the mean difference.">',
    '<p><a href="overview.svg">SVG</a> · <a href="overview.pdf">PDF</a></p>',
    '<h2>ggdist intervals</h2><img src="intervals.png" alt="Central 90 percent intervals for the mean difference and future measurements.">',
    '<h2>Interactive Plotly chart</h2><iframe title="Interactive prior contrast" src="contrast.html"></iframe>',
    '<h2>gt summary table</h2><iframe title="Prior summary table" src="summary.html"></iframe>',
    '<h2>Leaflet map</h2><p>Tiles require an internet connection. Map points are bundled with this example.</p><iframe title="Earthquake locations" src="earthquakes.html"></iframe>',
    '</html>'
  ),
  file.path(out, "index.html")
)
