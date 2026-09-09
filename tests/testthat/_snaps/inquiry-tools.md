# bundle grants leave unrelated capabilities denied

    Code
      inquiry_extra_tools("unknown")
    Condition
      Error in `inquiry_extra_tools()`:
      ! Choose supported Deputy tool bundles.

# tool forms preserve typed arguments and exact source words

    Code
      inquiry_tool_arguments(tool, list())
    Condition
      Error in `inquiry_tool_arguments()`:
      ! Supply wording before sending the tool request.

---

    Code
      inquiry_tool_arguments(custom, list(tool_arg_count = 1.5))
    Condition
      Error in `inquiry_tool_arguments()`:
      ! Supply a whole number for count.

