#' Connect Suppose to Meta's Muse Spark Contributor model
#'
#' Uses OpenRouter and its `OPENROUTER_API_KEY` environment variable by default.
#' Selecting the Contributor model permits prompts and outputs to be used to
#' improve Meta's products. Credentials are never added to scientific records.
#' Creating the client makes no inference request. A fresh client is needed for
#' each workbench session.
#' @param credentials Optional ellmer credentials; otherwise use its normal
#'   OpenRouter credential discovery.
#' @param model Explicit OpenRouter model identifier.
#' @param max_tokens Maximum output tokens per response, including reasoning.
#' @return An ellmer Chat object suitable for `suppose_app(chat_factory = ...)`.
#' @export
suppose_muse <- function(
  credentials = NULL,
  model = "meta/muse-spark-1.3-contributor",
  max_tokens = 4096L
) {
  rlang::check_installed("ellmer")
  check_text(model, "model")
  check_count(max_tokens, "max_tokens", 1, 65536)
  ellmer::chat_openrouter(
    model = model,
    credentials = credentials,
    params = ellmer::params(max_tokens = max_tokens),
    api_args = list(provider = list(require_parameters = TRUE)),
    echo = "none"
  )
}

#' Apply a completed assistant proposal for human review
#'
#' Appends a proposed revision, retaining the source conversation, model,
#' tool receipts, and exact proposal. This never accepts the formalization.
#' Proposals are bound to the complete source record, so intervening changes or
#' repeat application are rejected. An incomplete proposal can be retained as a
#' draft and clarified later.
#' @param x An elicitation record.
#' @param proposal A completed `suppose_proposal` from the assistant tools.
#' @param author Person choosing to apply the proposal.
#' @param corrections Optional named list of claim fields corrected by the
#'   reviewer. See [claim()]. Corrections retain the exact assistant proposal in
#'   provenance, clear its numerical model and judgments, and require `reason`.
#'   A numerical threshold cannot be set through this interpretation correction.
#' @param reason Why the reviewer changed the proposed interpretation.
#' @return A new record; prior entries and acceptances remain unchanged.
#' @export
apply_assistant_proposal <- function(
  x,
  proposal,
  author,
  corrections = NULL,
  reason = NULL
) {
  validate_record(x)
  check_seal(proposal, "suppose_proposal")
  check_text(author, "author")
  if (!identical(proposal$base_id, proposal_basis_id(x))) {
    abort_suppose(
      "The record changed after this proposal. Request a new proposal before applying it.",
      "stale"
    )
  }
  c <- proposal$claim
  corrected <- length(corrections) > 0L
  if (!is.null(corrections) && !is.list(corrections)) {
    abort_suppose("{.arg corrections} must be a named list of claim fields.")
  }
  if (corrected) {
    check_text(reason, "reason")
    allowed <- setdiff(names(formals(claim)), "author")
    if (
      is.null(names(corrections)) ||
        !all(nzchar(names(corrections))) ||
        anyDuplicated(names(corrections)) ||
        !all(names(corrections) %in% allowed)
    ) {
      abort_suppose(
        "Supply unique named claim fields to correct; see {.fn claim}."
      )
    }
    if (!is.null(corrections$threshold)) {
      abort_suppose(
        "Set a numerical threshold through a new model proposal, not an interpretation correction.",
        "unsupported"
      )
    }
    # Validate fields through the same revision API as manual claim editing.
    c <- do.call(
      revise_claim,
      c(list(c, author = author, reason = reason), corrections)
    )
    c$id <- NULL
    c$parent_id <- utils::tail(x$revisions, 1)[[1]]$claim$id
    c$threshold <- NULL
    c <- seal(c, "suppose_claim")
  }
  # The assistant proposes meaning; the human who applies it owns this revision.
  c$id <- NULL
  c$author <- author
  c <- seal(c, "suppose_claim")
  old <- utils::tail(x$revisions, 1)[[1]]$claim
  if (!identical(c$id, old$id) && !identical(c$parent_id, old$id)) {
    c$id <- NULL
    c$parent_id <- old$id
    c$reason <- proposal$reason
    c <- seal(c, "suppose_claim")
  }
  p <- if (corrected) NULL else proposal$candidate
  prediction <- if (corrected) NULL else proposal$prediction
  if (!is.null(p)) {
    p$id <- NULL
    p$claim <- c
    p <- seal(p, "suppose_prior")
    prediction$id <- NULL
    prediction$prior_id <- p$id
    prediction <- seal(prediction, "suppose_prediction")
  }
  assistance <- list(
    proposal = proposal,
    applied_by = author,
    applied_at = now_utc()
  )
  if (corrected) {
    assistance$corrections <- corrections
    assistance$correction_reason <- reason
  }
  assistance <- seal(assistance, "suppose_assistance")
  out <- record_revision(
    x,
    c,
    p,
    prediction,
    reason = if (corrected) reason else proposal$reason,
    judgments = if (corrected) list() else proposal$judgments,
    assistance = assistance
  )
  out
}

# The assistant boundary stores plain data, never provider credentials or
# executable model objects. All numerical previews use the same public R APIs.
assistant_prompt <- function() {
  paste(
    "You help a scientist express a belief and examine its consequences.",
    "The only supported numerical model is mean batch strength at 160 degC minus",
    "mean strength at 140 degC, in MPa, with jointly normal means and known batch SDs.",
    "Start by reading the retained formalization. Unsaved form edits are not available.",
    "Ask short questions about missing scope, units, target, and what an interval means.",
    "A plausible range is not a probability interval. Never invent probabilities, SDs,",
    "correlations, or observations. Only propose numerical values explicitly stated",
    "in the user's messages, using exact source quotes. Central probability intervals",
    "about population means can be fitted; ranges and qualitative answers stay drafts.",
    "Use propose_claim, propose_judgment, and propose_assumptions for cumulative changes.",
    "Use preview_proposal to obtain every numerical result you explain. An error is a",
    "request to clarify, not permission to repair the user's judgment silently.",
    "Show a consequential assumption and ask what could challenge it. Do not infer",
    "causality from two temperatures. Elicitation fit is not empirical validation.",
    "Proposals appear for human review only after your response completes.",
    "You cannot apply or accept anything. Keep responses concise, and distinguish",
    "proposed values, stored values, model consequences, and actual observations."
  )
}

check_quote <- function(quote, messages, numbers = numeric()) {
  check_text(quote, "source_quote")
  users <- vapply(
    Filter(function(m) identical(m$role, "user"), messages),
    `[[`,
    character(1),
    "text"
  )
  if (
    !any(vapply(users, function(s) grepl(quote, s, fixed = TRUE), logical(1)))
  ) {
    abort_suppose(
      "Quote the user's message exactly; this source quote was not found.",
      "source"
    )
  }
  # Separate interval dashes from minus signs, then compare whole number tokens.
  normalized <- gsub(
    "([0-9])[-\u2013\u2014]([0-9])",
    "\\1 to \\2",
    quote,
    perl = TRUE
  )
  tokens <- regmatches(
    normalized,
    gregexpr(
      "[-+]?[0-9]+(?:\\.[0-9]+)?(?:[eE][-+]?[0-9]+)?",
      normalized,
      perl = TRUE
    )
  )[[1]]
  found <- as.numeric(tokens)
  for (number in numbers) {
    if (!any(abs(found - number) <= 1e-9 * max(1, abs(number)))) {
      abort_suppose(
        "The proposed number {number} is absent from the source quote. Ask the user to state it explicitly.",
        "source"
      )
    }
  }
  invisible(quote)
}

proposal_changes <- function() {
  list(
    claim = list(),
    judgments = list(),
    assumptions = list(),
    sources = list()
  )
}

compile_proposal <- function(record, changes, context, general = FALSE) {
  validate_record(record)
  old <- utils::tail(record$revisions, 1)[[1]]
  c <- old$claim
  reason <- paste(
    unique(vapply(changes$sources, `[[`, character(1), "reason")),
    collapse = "; "
  )
  if (!nzchar(reason)) {
    reason <- "Inspect existing formalization"
  }
  if (length(changes$claim)) {
    c <- do.call(
      revise_claim,
      c(list(c, author = c$author, reason = reason), changes$claim)
    )
  }
  if (general) {
    old$candidate <- NULL
    old$prediction <- NULL
    old$assistance <- NULL
    old$judgments <- list()
  }
  js <- old$judgments
  if (!length(js) && !is.null(old$candidate)) {
    js <- old$candidate$judgments
  }
  for (j in changes$judgments) {
    keep <- vapply(
      js,
      function(existing) existing$condition != j$condition,
      logical(1)
    )
    js <- c(js[keep], list(j))
  }
  if (length(js)) {
    js <- js[order(vapply(js, `[[`, numeric(1), "condition"))]
  }
  rho <- changes$assumptions$correlation %||%
    old$candidate$correlation %||%
    old$assistance$proposal$changes$assumptions$correlation
  sd <- changes$assumptions$batch_sd %||%
    old$candidate$batch_sd %||%
    old$assistance$proposal$changes$assumptions$batch_sd
  seed <- old$prediction$seed %||% 47L
  p <- NULL
  prediction <- NULL
  issue <- NULL
  if (is.null(rho) || is.null(sd)) {
    issue <- if (general) {
      "No numerical model proposed. This interpretation can be reviewed on its own."
    } else {
      "Ask for correlation of uncertain means and both known batch SDs before fitting."
    }
  } else {
    tryCatch(
      {
        p <- fit_prior(c, js, correlation = rho, batch_sd = sd)
        prediction <- predict_prior(p, seed = seed)
      },
      suppose_error = function(e) {
        issue <<- cli::ansi_strip(conditionMessage(e))
      }
    )
  }
  seal(
    list(
      base_id = proposal_basis_id(record),
      claim = c,
      judgments = js,
      candidate = p,
      prediction = prediction,
      preview_issue = issue,
      changes = changes,
      reason = reason,
      context = context
    ),
    "suppose_proposal"
  )
}

new_proposal_session <- function(
  get_record,
  publish = function(x) NULL,
  model = "custom",
  provider = "custom",
  general = FALSE,
  result_display = NULL,
  publish_form = function(draft) NULL,
  get_form_state = function() list()
) {
  compile <- function(record, changes, context) {
    compile_proposal(record, changes, context, general = general)
  }
  state <- new.env(parent = emptyenv())
  state$messages <- list()
  state$pending <- NULL
  state$request <- NULL
  state$phase <- "idle"
  add_message <- function(role, text, status = "complete") {
    state$messages[[length(state$messages) + 1L]] <- list(
      role = role,
      text = text,
      status = status,
      created_at = now_utc()
    )
  }
  state$set_model <- function(new_model, new_provider) {
    if (identical(state$phase, "running")) {
      abort_suppose(
        "Finish or cancel the response before switching models.",
        "busy"
      )
    }
    check_text(new_model, "model")
    check_text(new_provider, "provider")
    model <<- new_model
    provider <<- new_provider
    invisible(NULL)
  }
  state$begin <- function(text) {
    if (identical(state$phase, "running")) {
      abort_suppose("An assistant response is already running.", "busy")
    }
    check_text(text, "message")
    record <- get_record()
    validate_record(record)
    id <- object_id(list(
      text = text,
      time = now_utc(),
      number = length(state$messages)
    ))
    add_message("user", text)
    previous <- state$pending
    if (!is.null(previous) && previous$base_id != proposal_basis_id(record)) {
      previous <- NULL
    }
    state$request <- list(
      id = id,
      base = record,
      changes = if (is.null(previous)) proposal_changes() else previous$changes,
      receipts = if (is.null(previous)) {
        list()
      } else {
        previous$context$tool_results
      },
      previous = previous,
      changed = FALSE,
      form_drafts = list(),
      form_state = get_form_state()
    )
    state$phase <- "running"
    publish(NULL)
    id
  }
  guard <- function(id) {
    if (state$phase != "running" || !identical(state$request$id, id)) {
      abort_suppose(
        "This assistant request is no longer active; its results cannot be applied.",
        "cancelled"
      )
    }
    if (
      !identical(
        proposal_basis_id(get_record()),
        proposal_basis_id(state$request$base)
      )
    ) {
      abort_suppose(
        "The record changed during the assistant response. Retry against the new revision.",
        "stale"
      )
    }
  }
  context <- function() {
    list(
      provider = provider,
      model = model,
      request_id = state$request$id,
      messages = state$messages,
      tool_results = state$request$receipts,
      runs = state$request$runs %||% list(),
      status = "complete"
    )
  }
  state$finish <- function(id, text, execution = NULL) {
    guard(id)
    if (!is.null(execution)) {
      state$request$runs <- c(
        state$request$previous$context$runs %||% list(),
        list(execution)
      )
    }
    if (!is.character(text) || length(text) != 1L || is.na(text)) {
      abort_suppose(
        "The assistant response must be a single text string.",
        "response"
      )
    }
    if (nzchar(trimws(text))) {
      add_message("assistant", text)
    }
    if (!state$request$changed && is.null(state$request$compiled)) {
      state$pending <- state$request$previous
    } else if (length(state$request$changes$sources)) {
      state$pending <- state$request$compiled %||%
        compile(
          state$request$base,
          state$request$changes,
          context()
        )
      state$pending$id <- NULL
      state$pending$context <- context()
      state$pending <- seal(state$pending, "suppose_proposal")
    } else {
      state$pending <- NULL
    }
    state$phase <- "complete"
    for (draft in state$request$form_drafts) {
      draft$id <- NULL
      draft$context <- context()
      publish_form(seal(draft, "suppose_form_draft"))
    }
    publish(state$pending)
    invisible(state$pending)
  }
  state$cancel <- function(reason = "cancelled") {
    if (state$phase != "running") {
      return(invisible(NULL))
    }
    add_message("assistant", paste("Response", reason), status = reason)
    state$pending <- state$request$previous
    state$phase <- reason
    publish(state$pending)
    invisible(NULL)
  }
  state$clear_proposal <- function() {
    state$pending <- NULL
    publish(NULL)
  }
  state$reset <- function() {
    state$cancel("cancelled")
    state$messages <- list()
    state$pending <- NULL
    state$request <- NULL
    state$phase <- "idle"
    publish(NULL)
  }
  state$tools <- function(id) {
    rlang::check_installed("ellmer")
    receipt <- function(name, args, result) {
      state$request$receipts[[length(state$request$receipts) + 1L]] <- list(
        tool = name,
        arguments = args,
        result = result
      )
      value <- jsonlite::toJSON(
        plain(result),
        auto_unbox = TRUE,
        null = "null",
        digits = NA
      )
      if (is.null(result_display)) {
        value
      } else {
        result_display(name, args, result, id, value)
      }
    }
    add_source <- function(tool, quote, reason) {
      check_text(reason, "reason")
      state$request$compiled <- NULL
      state$request$changed <- TRUE
      state$request$changes$sources[[
        length(state$request$changes$sources) + 1L
      ]] <- list(tool = tool, quote = quote, reason = reason)
    }
    if (general) {
      return(lapply(
        c(
          inquiry_tools(
            id,
            guard,
            state,
            receipt,
            add_source,
            context,
            compile
          ),
          workbench_form_tools(id, guard, state, receipt),
          measurement_form_tools(id, guard, state, receipt),
          list(research_design_tool(id, guard, state, receipt)),
          regression_research_tools(id, guard, state, receipt)
        ),
        compact_inquiry_tool
      ))
    }
    list(
      ellmer::tool(
        function() {
          guard(id)
          e <- utils::tail(state$request$base$revisions, 1)[[1]]
          receipt(
            "read_formalization",
            list(),
            list(
              claim = plain(e$claim),
              judgments = plain(e$judgments),
              assumptions = e$candidate$assumptions,
              correlation = e$candidate$correlation,
              batch_sd = e$candidate$batch_sd,
              summary = e$prediction$summary,
              prediction_id = e$prediction$id
            )
          )
        },
        "Read retained meaning, judgments, assumptions, and computed results.",
        name = "read_formalization"
      ),
      ellmer::tool(
        function(
          wording,
          source_quote,
          reason,
          scope = NULL,
          threshold = NULL
        ) {
          guard(id)
          check_quote(source_quote, state$messages, threshold %||% numeric())
          check_text(wording, "wording")
          check_text(scope, "scope", TRUE)
          if (!is.null(threshold)) {
            check_number(threshold, "threshold")
          }
          fields <- list(wording = wording)
          if (!is.null(scope)) {
            fields$scope <- scope
          }
          if (!is.null(threshold)) {
            fields$threshold <- threshold
          }
          # The target is an explicit proposal within this workbench's fixed model.
          fields$target <- "Mean batch strength at 160 degC minus mean batch strength at 140 degC"
          fields$units <- "MPa"
          state$request$changes$claim[names(fields)] <- fields
          add_source("propose_claim", source_quote, reason)
          receipt(
            "propose_claim",
            list(
              wording = wording,
              scope = scope,
              threshold = threshold,
              source_quote = source_quote
            ),
            "Claim proposal staged for human review; no record changed."
          )
        },
        "Propose clearer wording and optional scope/threshold from the user's exact words. Fixed target: mean 160 minus mean 140 degC, MPa.",
        arguments = list(
          wording = ellmer::type_string(),
          source_quote = ellmer::type_string(),
          reason = ellmer::type_string(),
          scope = ellmer::type_string(required = FALSE),
          threshold = ellmer::type_number(required = FALSE)
        ),
        name = "propose_claim"
      ),
      ellmer::tool(
        function(
          condition,
          quantity,
          source_quote,
          reason,
          lower = NULL,
          upper = NULL,
          probability = NULL
        ) {
          guard(id)
          check_number(condition, "condition")
          if (!condition %in% c(140, 160)) {
            abort_suppose(
              "This workbench supports conditions 140 and 160 degC.",
              "unsupported"
            )
          }
          if (!quantity %in% c("mean", "batch", "specimen", "qualitative")) {
            abort_suppose("Unsupported judgment quantity.", "unsupported")
          }
          if (xor(is.null(lower), is.null(upper))) {
            abort_suppose("Supply both interval endpoints, or neither.")
          }
          if (!is.null(lower)) {
            check_number(lower, "lower")
            check_number(upper, "upper")
          }
          if (!is.null(probability)) {
            check_number(probability, "probability", 0, 1)
            if (probability <= 0 || probability >= 1 || is.null(lower)) {
              abort_suppose(
                "State a probability strictly between 0 and 1 and both endpoints.",
                "probability"
              )
            }
          }
          check_quote(source_quote, state$messages, c(condition, lower, upper))
          if (!is.null(probability)) {
            tryCatch(
              check_quote(source_quote, state$messages, probability),
              suppose_source = function(e) {
                check_quote(source_quote, state$messages, probability * 100)
              }
            )
          }
          kind <- if (is.null(lower)) {
            "qualitative"
          } else if (is.null(probability)) {
            "range"
          } else {
            "quantile"
          }
          j <- judgment(
            condition,
            values = if (is.null(lower)) NULL else c(lower, upper),
            probabilities = if (is.null(probability)) {
              NULL
            } else {
              c((1 - probability) / 2, (1 + probability) / 2)
            },
            kind = kind,
            quantity = if (quantity == "qualitative") "shape" else quantity,
            units = "MPa",
            author = utils::tail(state$request$base$revisions, 1)[[
              1
            ]]$claim$author,
            answer = source_quote,
            rationale = reason,
            source = "User conversation; assistant-proposed interpretation"
          )
          state$request$changes$judgments[[as.character(condition)]] <- j
          add_source("propose_judgment", source_quote, reason)
          receipt(
            "propose_judgment",
            list(
              condition = condition,
              quantity = quantity,
              lower = lower,
              upper = upper,
              probability = probability,
              source_quote = source_quote
            ),
            list(status = "staged", kind = j$kind, issues = j$issues)
          )
        },
        "Propose one user-stated judgment. probability is the explicitly stated central interval mass (e.g. 0.9); omit it for a mere plausible range. Quote the condition and numbers exactly.",
        arguments = list(
          condition = ellmer::type_number(),
          quantity = ellmer::type_enum(c(
            "mean",
            "batch",
            "specimen",
            "qualitative"
          )),
          source_quote = ellmer::type_string(),
          reason = ellmer::type_string(),
          lower = ellmer::type_number(required = FALSE),
          upper = ellmer::type_number(required = FALSE),
          probability = ellmer::type_number(required = FALSE)
        ),
        name = "propose_judgment"
      ),
      ellmer::tool(
        function(correlation, sd_140, sd_160, source_quote, reason) {
          guard(id)
          check_number(correlation, "correlation", -1, 1)
          check_number(sd_140, "sd_140", 0)
          check_number(sd_160, "sd_160", 0)
          check_quote(
            source_quote,
            state$messages,
            c(correlation, sd_140, sd_160)
          )
          state$request$changes$assumptions <- list(
            correlation = correlation,
            batch_sd = c(sd_140, sd_160)
          )
          add_source("propose_assumptions", source_quote, reason)
          receipt(
            "propose_assumptions",
            list(
              correlation = correlation,
              batch_sd = c(sd_140, sd_160),
              source_quote = source_quote
            ),
            "Assumptions staged for review, not learned from the marginal intervals."
          )
        },
        "Propose explicitly user-supplied correlation of uncertain means and two known batch SDs (MPa).",
        arguments = list(
          correlation = ellmer::type_number(),
          sd_140 = ellmer::type_number(),
          sd_160 = ellmer::type_number(),
          source_quote = ellmer::type_string(),
          reason = ellmer::type_string()
        ),
        name = "propose_assumptions"
      ),
      ellmer::tool(
        function() {
          guard(id)
          p <- compile(
            state$request$base,
            state$request$changes,
            context()
          )
          state$request$compiled <- p
          receipt(
            "preview_proposal",
            list(),
            list(
              issue = p$preview_issue,
              summary = p$prediction$summary,
              prediction_id = p$prediction$id,
              fit_error = p$candidate$max_error,
              fit_ok = p$candidate$fit_ok,
              correlation = p$candidate$correlation,
              batch_sd = p$candidate$batch_sd,
              interpretation = "Prior model consequences, not empirical evidence."
            )
          )
        },
        "Compute a preview of staged changes using Suppose's R procedures; use this tool for all numerical explanations.",
        name = "preview_proposal"
      )
    )
  }
  state
}
