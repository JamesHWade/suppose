inquiry_history_options <- function(directory) {
  if (is.null(directory)) {
    return(FALSE)
  }
  check_text(directory, "history_dir")
  shinychat::history_options(
    store = inquiry_history_store(directory),
    scope = "suppose-local",
    restore_mode = "url",
    title = NULL,
    max_store_mb = NULL
  )
}

encode_inquiry_history <- function(
  record,
  proposal,
  messages,
  activity = NULL,
  cards = NULL,
  forms = NULL,
  questions = NULL
) {
  as.character(json_data(list(
    version = 1L,
    record = record,
    proposal = proposal,
    messages = messages,
    activity = activity,
    cards = cards,
    forms = forms,
    questions = questions
  )))
}

decode_inquiry_history <- function(value) {
  if (is.null(value)) {
    return(list(record = NULL, proposal = NULL, messages = list()))
  }
  state <- jsonlite::fromJSON(
    value,
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  if (!identical(state$version, 1L)) {
    abort_suppose("Unsupported conversation state version.")
  }
  state <- restore_record_types(state)
  for (draft in state$forms) {
    check_seal(draft, "suppose_form_draft")
  }
  if (!is.null(state$record)) {
    validate_record(state$record)
    class(state$record) <- c("suppose_record", "list")
  }
  state
}

# Tool errors can contain traces with calls to closures and external pointers.
# Persist their message as a simple condition; execution/UI receipts stay native.
history_serializable_turn <- function(x) {
  if (inherits(x, "condition")) {
    return(simpleError(conditionMessage(x)))
  }
  if (is.list(x)) {
    x[] <- lapply(x, history_serializable_turn)
  }
  x
}

inquiry_history_store <- function(directory) {
  super <- NULL # R6 supplies this binding in method environments.
  R6::R6Class(
    "SupposeConversationStore",
    inherit = shinychat::FileConversationStore,
    public = list(put = function(partition, record) {
      record$nodes <- lapply(record$nodes, function(node) {
        node$turns <- lapply(node$turns, history_serializable_turn)
        node
      })
      super$put(partition, record)
    })
  )$new(directory)
}
