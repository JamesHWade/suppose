# Palette and typography drawn from the package hex sticker.
suppose_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bg = "#fbf8ff",
    fg = "#3b163f",
    primary = "#633b83",
    secondary = "#79508d",
    base_font = c("Avenir Next", "Avenir", "system-ui", "sans-serif"),
    heading_font = c("Avenir Next", "Avenir", "system-ui", "sans-serif"),
    "headings-font-weight" = "700",
    "border-color" = "#dfd3ec",
    "input-bg" = "#ffffff",
    "card-bg" = "#fffdf8",
    "border-radius" = "0.65rem"
  )
}

suppose_brand_mark <- function() {
  shiny::addResourcePath(
    "suppose-brand",
    system.file("www", package = "suppose")
  )
  shiny::tags$img(
    src = "suppose-brand/suppose-logo.png",
    alt = "Suppose: a fox watching dandelion seeds",
    width = 86,
    height = 100,
    class = "suppose-brand-mark"
  )
}
