# a hypothetical question cannot be extracted as an expectation

    Code
      inquiry_statement_sources("three teams say yes in interviews", messages,
        "expectations")
    Condition
      Error in `FUN()`:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: I have not offered or sold this yet. If three teams say yes in interviews, would that establish demand?

---

    Code
      inquiry_statement_sources(
        "If three teams say yes in interviews, would that establish demand?",
        messages, "expectations")
    Condition
      Error in `FUN()`:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: I have not offered or sold this yet. If three teams say yes in interviews, would that establish demand?

# source checks retain negation and conditions with the message context

    Code
      inquiry_statement_sources("expect three teams to pay.", messages,
        "expectations")
    Condition
      Error in `FUN()`:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: This is an invented case. I do not expect three teams to pay. If the offer changes, I expect the result to change too.

---

    Code
      inquiry_statement_sources("I expect the result to change too.", messages,
        "expectations")
    Condition
      Error in `FUN()`:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: This is an invented case. I do not expect three teams to pay. If the offer changes, I expect the result to change too.

# user adoption is distinct from an assistant suggestion

    Code
      inquiry_statement_sources(suggestion, messages, "assumptions")
    Condition
      Error in `check_quote()`:
      ! Quote the user's message exactly; this source quote was not found.

# decimal points are not quotation boundaries

    Code
      inquiry_statement_sources("5, I expect fewer completions.", messages,
        "expectations")
    Condition
      Error in `FUN()`:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: If the rate exceeds 0.5, I expect fewer completions.

---

    Code
      inquiry_statement_sources("If the rate exceeds 0.", messages, "expectations")
    Condition
      Error in `FUN()`:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: If the rate exceeds 0.5, I expect fewer completions.

# units are not invented by taking letters from ordinary words

    Code
      inquiry_stated_units("s", messages)
    Condition
      Error in `inquiry_stated_units()`:
      ! Use units stated by the user, or omit units while they are unknown. Put a suggested measurement in ideas.

---

    Code
      inquiry_stated_units("m", messages)
    Condition
      Error in `inquiry_stated_units()`:
      ! Use units stated by the user, or omit units while they are unknown. Put a suggested measurement in ideas.

# missing and malformed tool fields cannot become invented text

    Code
      inquiry_text_array(list(list(text = "Hidden structure")), "ideas")
    Condition
      Error in `check_strings()`:
      ! `ideas` must be a character vector without missing or empty values.

---

    Code
      inquiry_text_array(list(42), "ideas")
    Condition
      Error in `check_strings()`:
      ! `ideas` must be a character vector without missing or empty values.

---

    Code
      inquiry_text_array("null", "expectations")
    Condition
      Error in `inquiry_text_array()`:
      ! Omit unknown `expectations` rather than supplying the string 'null'.

# invalid interpretation tools are atomic and unknowns clear old fields

    Code
      tool(words, words, "Clarify", units = "invented units")
    Condition
      Error:
      ! Use units stated by the user, or omit units while they are unknown. Put a suggested measurement in ideas.

---

    Code
      tool(words, words, "Clarify", expectations = "three teams say yes")
    Condition
      Error:
      ! Keep each `expectations` item as a complete verbatim user statement, including conditions and negation.
      i Do not extract a fragment or turn a question into a statement. Use open questions or ideas instead.
      i Source context: If three teams say yes, would that establish demand?

---

    Code
      tool(words, words, "", target = "Demand")
    Condition
      Error:
      ! `reason` must be one nonempty string.

