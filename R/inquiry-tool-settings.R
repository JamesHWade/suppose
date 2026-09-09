inquiry_tool_bundles <- function() {
  list(
    files = list(
      label = "Read files and data",
      detail = "Explore local documents and CSV data. Find files and search their contents.",
      tools = c(
        "read_file",
        "read_markdown",
        "read_csv",
        "list_files",
        "glob_files",
        "grep_files"
      )
    ),
    write = list(
      label = "Write and edit files",
      detail = "Create and edit files inside the working folder.",
      tools = c("write_file", "edit_file", "multi_edit")
    ),
    web = list(
      label = "Search and read the web",
      detail = "Find information online and read web pages.",
      tools = c("web_search", "web_fetch")
    ),
    r = list(
      label = "Run R code",
      detail = "Run calculations and simulations, create plots, and revise them in conversation. Can also change files and access the network.",
      tools = "run_r_code"
    ),
    shell = list(
      label = "Run shell commands",
      detail = "Run local programs and terminal commands. Can change files and access the network.",
      tools = "run_bash"
    )
  )
}

inquiry_extra_tools <- function(bundles) {
  if (
    !is.character(bundles) ||
      anyNA(bundles) ||
      !all(bundles %in% names(inquiry_tool_bundles()))
  ) {
    abort_suppose("Choose supported Deputy tool bundles.", "tools")
  }
  names <- unlist(lapply(
    inquiry_tool_bundles()[unique(bundles)],
    `[[`,
    "tools"
  ))
  Filter(function(tool) tool@name %in% names, deputy::tools_all())
}

inquiry_permissions <- function(bundles, working_dir) {
  core <- c(
    "read_inquiry",
    "propose_interpretation",
    "propose_normal_contrast",
    "preview_proposal",
    "draft_model_extension",
    "draft_sensitivity",
    "draft_regression",
    "draft_measurements",
    "draft_research_design",
    "draft_regression_test",
    "draft_regression_sensitivity",
    "deputy_read_tool_result"
  )
  extra <- vapply(
    inquiry_extra_tools(bundles),
    function(tool) tool@name,
    character(1)
  )
  args <- list(
    mode = "standard",
    file_read = "files" %in% bundles,
    file_write = if ("write" %in% bundles) working_dir else FALSE,
    bash = "shell" %in% bundles,
    r_code = "r" %in% bundles,
    web = "web" %in% bundles,
    install_packages = FALSE,
    tool_allowlist = c(core, extra)
  )
  native <- do.call(deputy::Permissions, args)
  args$can_use_tool <- function(tool_name, tool_input, context) {
    if (tool_name %in% core) {
      return(deputy::PermissionResultAllow())
    }
    deputy::permissions_check(native, tool_name, tool_input, context)
  }
  do.call(deputy::Permissions, args)
}

inquiry_agent_config <- function(agent) {
  if (is.null(agent) || !is.function(agent$inquiry_config)) {
    return(NULL)
  }
  agent$inquiry_config()
}

inquiry_agent_tools <- function(agent, assistant) {
  core <- assistant$tools(NULL)
  extras <- if (!is.null(agent) && is.function(agent$inquiry_extra_tools)) {
    agent$inquiry_extra_tools()
  } else {
    list()
  }
  tools <- c(core, extras)
  if (!is.null(agent)) {
    reader <- agent$get_tools()[["deputy_read_tool_result"]]
    if (!is.null(reader)) tools <- c(tools, list(reader))
  }
  stats::setNames(tools, vapply(tools, function(tool) tool@name, character(1)))
}
