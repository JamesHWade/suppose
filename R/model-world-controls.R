world_range_input <- function(
  id,
  label,
  min,
  max,
  value,
  step = 1,
  values = NULL
) {
  position <- if (is.null(values)) value else which.min(abs(values - value))
  shown <- if (is.null(values)) position else values[position]
  shiny::tags$div(
    class = 'shiny-input-container world-range-container',
    shiny::tags$label(id = paste0(id, '-label'), `for` = id, label),
    shiny::tags$output(id = paste0(id, '-value'), `for` = id, shown),
    shiny::tags$input(
      id = id,
      type = 'range',
      class = 'suppose-world-range',
      min = if (is.null(values)) min else 1,
      max = if (is.null(values)) max else length(values),
      step = if (is.null(values)) step else 1,
      value = position,
      `aria-valuetext` = as.character(shown),
      `data-values` = if (is.null(values)) {
        NULL
      } else {
        as.character(jsonlite::toJSON(values, auto_unbox = FALSE))
      }
    ),
    shiny::tags$div(
      class = 'world-range-ends',
      shiny::tags$span(id = paste0(id, '-min'), min),
      shiny::tags$span(id = paste0(id, '-max'), max)
    )
  )
}

world_update_slider <- function(
  session,
  id,
  label = NULL,
  min = NULL,
  max = NULL,
  value = NULL,
  step = NULL,
  values = NULL
) {
  data <- list(
    label = label,
    min = min,
    max = max,
    value = value,
    step = step,
    values = values
  )
  data <- data[!vapply(data, is.null, logical(1))]
  session$sendInputMessage(id, data)
}
