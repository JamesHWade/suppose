# The chat UI and the conversations it keeps: binding shinychat to the agent,
# saving Suppose's record with each conversation and restoring it, and the
# download and reopen controls. `agent` is the environment holding the current
# `client` and its `chat` binding. `restore_forms(saved, record)` restores
# form drafts saved with a conversation.
inquiry_history_binding <- function(
  input,
  output,
  session,
  agent,
  state,
  history_dir,
  assistant,
  decision_cards,
  question_cards,
  busy,
  safely,
  capture_activity,
  reset_runtime,
  restore_forms
) {
  current <- state$current
  proposal <- state$proposal
  forms <- state$forms
  editing_proposal <- state$editing_proposal
  runtime_activity <- state$runtime_activity
  transcript <- state$transcript
  status <- state$status
  bind_chat <- function() {
    chat <- shinychat::chat_server(
      "inquiry",
      agent$client,
      history = inquiry_history_options(history_dir)
    )
    agent$chat <- chat
    if (!is.null(history_dir)) {
      chat$history$on_save(function(values) {
        values$suppose <- encode_inquiry_history(
          shiny::isolate(current()),
          shiny::isolate(proposal()),
          assistant$messages,
          shiny::isolate(runtime_activity()),
          shiny::isolate(decision_cards$entries()),
          shiny::isolate(forms()),
          shiny::isolate(question_cards$entries())
        )
        values
      })
      chat$history$on_restore(function(values) {
        saved <- decode_inquiry_history(values$suppose)
        forms(saved$forms %||% list())
        assistant$reset()
        assistant$messages <- saved$messages
        assistant$pending <- saved$proposal
        current(saved$record)
        proposal(saved$proposal)
        editing_proposal(NULL)
        runtime_activity(
          saved$activity %||%
            inquiry_saved_activity(saved$record, saved$proposal)
        )
        decision_cards$restore(saved$cards)
        question_cards$restore(saved$questions)
        # Restore after record-lineage observers clear the previous form state.
        session$onFlushed(
          function() {
            shiny::isolate(restore_forms(saved$forms, saved$record))
          },
          once = TRUE
        )
        transcript(assistant$messages)
        reset_runtime()
        status(
          "Conversation and developing record restored. R starts fresh; saved results remain available."
        )
      })
      for (event in c(
        "inquiry_history_new",
        "inquiry_history_select",
        "inquiry_history_delete"
      )) {
        local({
          name <- event
          shiny::observeEvent(
            input[[name]],
            {
              if (assistant$phase == "running") {
                shiny::freezeReactiveValue(input, name)
                shiny::showNotification(
                  "Finish or cancel the response before switching conversations."
                )
              }
            },
            priority = 200
          )
        })
      }
      previous_id <- NULL
      shiny::observe(
        {
          id <- chat$history$conversation_id()
          if (is.null(id) && !is.null(previous_id)) {
            assistant$reset()
            forms(list())
            current(NULL)
            proposal(NULL)
            editing_proposal(NULL)
            transcript(list())
            runtime_activity(NULL)
            decision_cards$restore(NULL)
            question_cards$restore(NULL)
            reset_runtime()
            status("Your record takes shape as we talk.")
          }
          previous_id <<- id
        },
        priority = 100
      )
      shiny::observe(
        {
          current()
          proposal()
          transcript()
          runtime_activity()
          decision_cards$entries()
          question_cards$entries()
          forms()
          if (
            assistant$phase != "running" &&
              !is.null(shiny::isolate(chat$history$conversation_id()))
          ) {
            safely(shiny::isolate(chat$history$save()))
          }
        },
        priority = -100
      )
    }
    shiny::observeEvent(
      chat$last_turn(),
      safely({
        if (assistant$phase != "running") {
          return()
        }
        run <- agent$client$last_run()
        capture_activity()
        if (is.null(run) || !isTRUE(deputy::result_is_success(run))) {
          assistant$cancel("stopped")
          transcript(assistant$messages)
          status(
            "The agent stopped before completing this response. No incomplete proposal was applied."
          )
          return()
        }
        tryCatch(
          assistant$finish(
            assistant$request$id,
            ellmer::contents_text(chat$last_turn()),
            execution = deputy_run_receipt(agent$client)
          ),
          error = function(e) {
            assistant$cancel("failed")
            stop(e)
          }
        )
        question_cards$complete(assistant$request$id)
        transcript(assistant$messages)
        status(
          if (question_cards$waiting(assistant$request$id)) {
            "Answer the questions in the chat to continue, or reply in your own words."
          } else if (length(assistant$request$form_drafts)) {
            "Chat prepared form values and a preview. Review the suggested assumptions in the open Record panel."
          } else if (is.null(proposal())) {
            "No record suggestion was created for this response. Your retained interpretation is unchanged."
          } else if (identical(proposal()$id, assistant$request$previous$id)) {
            "The existing suggestion is unchanged. Review it with the Record button."
          } else {
            "A proposed interpretation is ready for review. Apply it only if it expresses your meaning."
          }
        )
      })
    )
    shiny::observeEvent(chat$last_error(), {
      capture_activity()
      assistant$cancel("failed")
      transcript(assistant$messages)
      status(
        "The model response failed. No incomplete suggestion was applied. Send your message again to retry, or use the editor."
      )
    })
    shiny::observeEvent(
      input$inquiry_cancel,
      {
        assistant$cancel()
        transcript(assistant$messages)
        status("Response cancelled. Incomplete suggestions were discarded.")
      },
      priority = 100
    )
  }
  # Shows the retained messages in the chat and gives them to the agent.
  restore_chat <- function() {
    if (!is.null(agent$chat)) {
      if (is.null(history_dir)) {
        agent$chat$clear()
      } else {
        # Initial records and portable imports enter an unselected conversation.
        # shinychat reserves clear() for chats without persistent history.
        if (!is.null(agent$chat$history$conversation_id())) {
          abort_suppose(
            "Start a new conversation before importing a saved record."
          )
        }
        agent$chat$new_chat()
      }
    } else {
      shinychat::chat_clear("inquiry")
    }
    for (m in assistant$messages) {
      shinychat::chat_append("inquiry", m$text, role = m$role)
    }
    if (!is.null(agent$client)) {
      agent$client$set_turns(inquiry_turns(assistant$messages))
    }
  }
  # An initial record's conversation, unless a saved conversation was selected.
  restore_initial <- function() {
    if (
      length(assistant$messages) &&
        (is.null(agent$chat) ||
          is.null(history_dir) ||
          is.null(agent$chat$history$conversation_id()))
    ) {
      restore_chat()
    }
  }
  # Downloading the conversation and record, and reopening a downloaded copy.
  serve_files <- function() {
    reopen_status <- shiny::reactiveVal(NULL)
    output$reopen_status <- shiny::renderText(reopen_status())
    output$save_notice <- shiny::renderText({
      if (!is.null(history_dir) && !is.null(agent$client)) {
        "Conversations, records and pending suggestions are saved automatically. Apply editor changes before leaving. Download a separate copy here."
      } else {
        "Save before closing. Unapplied suggestions and unsaved editor changes are not retained as revisions."
      }
    })
    output$save <- shiny::downloadHandler(
      filename = function() "suppose-conversation.json",
      content = function(path) {
        shiny::req(current())
        write_record(
          record_conversation(current(), assistant$messages),
          path,
          overwrite = TRUE
        )
      },
      contentType = "application/json"
    )
    shiny::observeEvent(
      input$reopen,
      tryCatch(
        {
          busy()
          if (
            !is.null(agent$chat) &&
              !is.null(history_dir) &&
              !is.null(agent$chat$history$conversation_id())
          ) {
            abort_suppose(
              "Start a new conversation before importing a saved record."
            )
          }
          out <- read_record(input$reopen$datapath)
          forms(list())
          assistant$reset()
          assistant$messages <- out$conversation %||%
            latest_initial_messages(out)
          current(out)
          decision_cards$restore(NULL)
          question_cards$restore(NULL)
          runtime_activity(inquiry_saved_activity(out))
          transcript(assistant$messages)
          reset_runtime()
          restore_chat()
          status(
            "Conversation and record reopened. Stored results were not recomputed."
          )
          reopen_status(status())
        },
        error = function(e) {
          message <- cli::ansi_strip(conditionMessage(e))
          status(message)
          reopen_status(message)
        }
      )
    )
  }
  list(
    bind_chat = bind_chat,
    restore_initial = restore_initial,
    serve_files = serve_files
  )
}
