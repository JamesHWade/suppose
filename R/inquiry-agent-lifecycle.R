# The Deputy agent behind the conversation: creating it, switching or
# rebuilding it, recording R analyses from its runs, and closing it. `agent`
# is an environment holding the current `client` and its `chat` binding.

inquiry_new_agent <- function(chat_factory, agent_factory) {
  agent <- if (!is.null(agent_factory)) {
    agent_factory()
  } else if (!is.null(chat_factory)) {
    suppose_agent(chat_factory())
  } else {
    NULL
  }
  if (!is.null(agent) && !inherits(agent, "Agent")) {
    abort_suppose("agent_factory must return a fresh Deputy Agent.", "agent")
  }
  agent
}

# A new agent starts from Suppose's prompt and the visible transcript.
inquiry_prepare_agent <- function(client, messages) {
  if (!is.null(client)) {
    client$set_system_prompt(inquiry_prompt())
    if (length(messages)) {
      client$set_turns(inquiry_turns(messages))
    }
  }
  invisible(client)
}

# `bind_chat()` binds the chat UI to the first agent, `register_chat(chat)`
# connects the model and tool controls to it, and `reset_world()` resets the
# model-world walkthrough.
inquiry_agent_lifecycle <- function(
  input,
  session,
  agent,
  state,
  assistant,
  busy,
  bind_chat,
  register_chat,
  reset_world
) {
  current <- state$current
  runtime_activity <- state$runtime_activity
  model_version <- state$model_version
  capture_activity <- function() {
    run <- agent$client$last_run()
    if (
      !is.null(run) &&
        !identical(run$run_id, assistant$request$runtime_previous_id)
    ) {
      runtime_activity(inquiry_run_activity(agent$client))
    }
  }
  switch_agent <- function(new_agent, preserve_session = TRUE) {
    busy()
    if (!inherits(new_agent, "Agent")) {
      abort_suppose("The selected client must be a Deputy Agent.", "agent")
    }
    if (!is.null(agent$client) && preserve_session) {
      transfer_inquiry_session(agent$client, new_agent)
    } else {
      new_agent$set_system_prompt(inquiry_prompt())
      new_agent$set_turns(inquiry_turns(assistant$messages))
    }
    if (!is.null(agent$chat)) {
      # Rebinding native history must not replay the last new/select/edit event.
      for (event in c(
        "history_new",
        "history_select",
        "history_rename",
        "history_delete",
        "message_edit",
        "message_navigate"
      )) {
        shiny::freezeReactiveValue(input, paste0("inquiry_", event))
      }
      agent$chat$set_client(new_agent, sync = FALSE)
    }
    if (!is.null(agent$client) && is.function(agent$client$inquiry_close)) {
      agent$client$inquiry_close()
    }
    agent$client <- new_agent
    assistant$set_model(agent$client$get_model(), "deputy")
    if (is.null(agent$chat)) {
      bind_chat()
      register_chat(agent$chat)
    }
    model_version(model_version() + 1L)
  }
  reset_runtime <- function() {
    reset_world()
    shiny::isolate({
      config <- inquiry_agent_config(agent$client)
      if (!is.null(config)) {
        config$conversation_id <- basename(tempfile("conversation_"))
        switch_agent(
          agent$client$inquiry_reconfigure(config),
          preserve_session = FALSE
        )
      }
    })
  }
  remove_analysis_observer <- NULL
  bind_analysis_capture <- function(id) {
    if (is.function(remove_analysis_observer)) {
      remove_analysis_observer()
    }
    if (is.null(agent$client)) {
      return(invisible(NULL))
    }
    owner <- agent$client
    base <- assistant$request$base
    prompt <- utils::tail(assistant$messages, 1)[[1]]$text
    remove_analysis_observer <<- owner$on_tool_result(function(result) {
      execution <- result@extra$deputy_r
      if (
        is.null(execution) ||
          !identical(owner, agent$client) ||
          !identical(assistant$request$id, id) ||
          !identical(
            proposal_basis_id(shiny::isolate(current())),
            proposal_basis_id(base)
          )
      ) {
        return(invisible(NULL))
      }
      current(record_analysis(
        shiny::isolate(current()),
        execution,
        source_prompt = prompt,
        model = owner$get_model(),
        request_id = id
      ))
    })
  }
  session$onSessionEnded(function() {
    if (is.function(remove_analysis_observer)) {
      remove_analysis_observer()
    }
    if (!is.null(agent$client) && is.function(agent$client$inquiry_close)) {
      agent$client$inquiry_close()
    }
  })
  list(
    capture_activity = capture_activity,
    switch_agent = switch_agent,
    reset_runtime = reset_runtime,
    bind_analysis_capture = bind_analysis_capture
  )
}
