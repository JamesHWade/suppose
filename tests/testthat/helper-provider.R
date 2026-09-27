# A scripted OpenAI-compatible provider in a background R process. A request
# that is not answering a tool gets one call to `tool_name`; a request that
# carries the tool's result gets a short text reply. Deputy then runs a real
# turn, so its permission checks apply as they do in the workbench.
local_scripted_provider <- function(
  tool_name,
  arguments,
  env = parent.frame()
) {
  skip_if_not_installed("callr")
  skip_if_not_installed("httpuv")
  port <- httpuv::randomPort()
  process <- callr::r_bg(
    function(port, tool_name, arguments) {
      json <- function(x) {
        as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
      }
      usage <- list(
        prompt_tokens = 10L,
        completion_tokens = 5L,
        total_tokens = 15L
      )
      reply <- function(body) {
        messages <- body$messages
        answering <- identical(messages[[length(messages)]]$role, "tool")
        call <- list(
          id = "scripted_call",
          type = "function",
          `function` = list(name = tool_name, arguments = json(arguments))
        )
        finish <- if (answering) "stop" else "tool_calls"
        if (!isTRUE(body$stream)) {
          message <- if (answering) {
            list(role = "assistant", content = "Scripted reply.")
          } else {
            list(role = "assistant", content = NULL, tool_calls = list(call))
          }
          return(list(
            type = "application/json",
            text = json(list(
              id = "scripted",
              object = "chat.completion",
              model = "fixture",
              choices = list(list(
                index = 0L,
                message = message,
                finish_reason = finish
              )),
              usage = usage
            ))
          ))
        }
        delta <- if (answering) {
          list(role = "assistant", content = "Scripted reply.")
        } else {
          list(role = "assistant", tool_calls = list(c(list(index = 0L), call)))
        }
        chunk <- function(choices, extra = list()) {
          paste0(
            "data: ",
            json(c(
              list(
                id = "scripted",
                object = "chat.completion.chunk",
                model = "fixture",
                choices = choices
              ),
              extra
            )),
            "\n\n"
          )
        }
        list(
          type = "text/event-stream",
          text = paste0(
            chunk(list(list(index = 0L, delta = delta, finish_reason = NULL))),
            chunk(list(list(
              index = 0L,
              delta = structure(list(), names = character()),
              finish_reason = finish
            ))),
            chunk(list(), list(usage = usage)),
            "data: [DONE]\n\n"
          )
        )
      }
      httpuv::runServer(
        "127.0.0.1",
        port,
        list(call = function(req) {
          body <- jsonlite::fromJSON(
            rawToChar(req$rook.input$read()),
            simplifyVector = FALSE
          )
          out <- reply(body)
          list(
            status = 200L,
            headers = list(`Content-Type` = out$type),
            body = out$text
          )
        })
      )
    },
    args = list(port = port, tool_name = tool_name, arguments = arguments)
  )
  withr::defer(process$kill(), envir = env)
  deadline <- Sys.time() + 20
  repeat {
    listening <- tryCatch(
      {
        connection <- suppressWarnings(socketConnection(
          "127.0.0.1",
          port,
          open = "r+",
          timeout = 1
        ))
        close(connection)
        TRUE
      },
      error = function(e) FALSE
    )
    if (listening) {
      break
    }
    if (!process$is_alive()) {
      stop("The scripted provider stopped: ", process$read_all_error())
    }
    if (Sys.time() > deadline) {
      stop("The scripted provider did not start listening.")
    }
    Sys.sleep(0.1)
  }
  paste0("http://127.0.0.1:", port, "/v1")
}
