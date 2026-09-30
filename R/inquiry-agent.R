# The oldest Deputy with the APIs the workbench uses, such as RSession,
# AskUserDeferred and tool_metadata(). DESCRIPTION declares the same floor.
deputy_version <- "0.0.0.9001"

#' Create the Deputy agent used by the inquiry workbench
#'
#' The returned Deputy Agent is passed directly to `shinychat::chat_server()`.
#' Suppose attaches its four session-bound inquiry tools. Deputy owns model
#' execution, permissions, usage limits, streaming and cancellation. Optional
#' Deputy bundles are disabled by default and can be enabled in the Tools modal.
#' @param chat An ellmer Chat, defaulting to [suppose_muse()].
#' @param usage_limits Optional Deputy UsageLimits. Defaults to eight model
#'   requests and sixteen tool calls per response, failing on limit exhaustion.
#' @param context_policy Optional Deputy ContextPolicy.
#' @param bundles Optional Deputy bundles: `files`, `write`, `web`, `r`, `shell`.
#' @param working_dir Existing working folder. File writes are restricted to this
#'   folder. File reads and trusted R/shell execution use the local account's access;
#'   the working folder is not an OS sandbox.
#' @param conversation_id Immutable identity for this open conversation.
#'   Defaults to a fresh local identifier. Reopening creates a new R process.
#' @return A fresh `deputy::Agent` for one workbench session.
#' @export
suppose_agent <- function(
  chat = suppose_muse(),
  usage_limits = NULL,
  context_policy = NULL,
  bundles = character(),
  working_dir = getwd(),
  conversation_id = basename(tempfile("inquiry_"))
) {
  rlang::check_installed("deputy", version = deputy_version)
  extras <- inquiry_extra_tools(bundles)
  check_text(working_dir, "working_dir")
  if (!dir.exists(working_dir)) {
    abort_suppose("Choose an existing working folder.", "tools")
  }
  working_dir <- normalizePath(working_dir, mustWork = TRUE)
  config <- list(
    bundles = unique(bundles),
    working_dir = working_dir,
    conversation_id = conversation_id,
    usage_limits = usage_limits %||%
      deputy::UsageLimits(
        max_requests = 8,
        max_tool_calls = 16,
        on_exceed = "error"
      ),
    context_policy = context_policy %||% deputy::ContextPolicy()
  )
  # Capture a fresh transport before Deputy installs run callbacks. Reconfiguration
  # preserves provider credentials/parameters without copying an old Agent's hooks.
  template <- chat$clone(deep = TRUE)
  rebuild <- function(config) {
    do.call(suppose_agent, c(list(chat = template$clone(deep = TRUE)), config))
  }
  agent <- inquiry_agent_class(rebuild, config, extras)$new(
    chat = chat,
    tools = extras,
    system_prompt = inquiry_prompt(),
    permissions = inquiry_permissions(bundles, working_dir),
    working_dir = working_dir,
    usage_limits = config$usage_limits,
    context_policy = config$context_policy,
    run_context = list(suppose_conversation = conversation_id),
    enable_file_checkpointing = FALSE,
    agent_name = "Suppose"
  )
  agent$set_tools(agent$inquiry_extra_tools())
  agent
}

deputy_run_receipt <- function(agent) {
  r <- agent$last_run()
  if (is.null(r)) {
    return(NULL)
  }
  list(
    runtime = "deputy",
    model = agent$get_model(),
    runtime_version = as.character(utils::packageVersion("deputy")),
    run_id = r$run_id,
    agent_id = r$agent_id,
    session_id = r$session_id,
    stop_reason = r$stop_reason,
    duration = r$duration,
    usage = lapply(
      stats::setNames(
        c(
          "requests",
          "tool_calls",
          "input_tokens",
          "output_tokens",
          "total_tokens"
        ),
        c(
          "requests",
          "tool_calls",
          "input_tokens",
          "output_tokens",
          "total_tokens"
        )
      ),
      function(nm) S7::prop(r$usage, nm)
    )
  )
}

# Deputy's Agent with the inquiry's R session and tool settings. Streaming is
# Deputy's own: it takes shinychat's spliced input and resets a reused
# cancelled controller once a run is accepted.
inquiry_agent_class <- function(
  rebuild = NULL,
  config = NULL,
  extras = list()
) {
  self <- private <- NULL # R6 supplies these bindings.
  R6::R6Class(
    "SupposeAgent",
    inherit = deputy::Agent,
    private = list(inquiry_runtime = NULL),
    public = list(
      inquiry_config = function() config,
      inquiry_extra_tools = function() {
        if (!"r" %in% config$bundles) {
          return(extras)
        }
        if (is.null(private$inquiry_runtime)) {
          private$inquiry_runtime <- deputy::RSession$new(self)
        }
        c(
          Filter(function(tool) tool@name != "run_r_code", extras),
          private$inquiry_runtime$tools()
        )
      },
      inquiry_close = function() {
        if (!is.null(private$inquiry_runtime)) {
          private$inquiry_runtime$close()
        }
        private$inquiry_runtime <- NULL
        invisible(NULL)
      },
      inquiry_r_status = function() {
        if (is.null(private$inquiry_runtime)) {
          NULL
        } else {
          private$inquiry_runtime$status()
        }
      },
      inquiry_reconfigure = function(settings) {
        if (is.null(rebuild)) {
          abort_suppose("This agent cannot be reconfigured.", "tools")
        }
        rebuild(settings)
      }
    )
  )
}
