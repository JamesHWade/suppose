# reviewer corrections preserve the exact suggestion and clear numerical consequences

    Code
      apply_assistant_proposal(corrected, p, "Reviewer", corrections = list(wording = "Another edit"),
      reason = "Again")
    Condition
      Error in `apply_assistant_proposal()`:
      ! The record changed after this proposal. Request a new proposal before applying it.

# correction requires valid fields and a reason

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = list(wording = "A change"))
    Condition
      Error in `check_text()`:
      ! `reason` must be one nonempty string.

---

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = list(invented_field = "A change"),
      reason = "Clarify")
    Condition
      Error in `apply_assistant_proposal()`:
      ! Supply unique named claim fields to correct; see `claim()`.

---

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = list(wording = ""),
      reason = "Clarify")
    Condition
      Error in `check_text()`:
      ! `wording` must be one nonempty string.

---

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = "A change", reason = "Clarify")
    Condition
      Error in `apply_assistant_proposal()`:
      ! `corrections` must be a named list of claim fields.

---

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = list(author = "Someone else"),
      reason = "Clarify")
    Condition
      Error in `apply_assistant_proposal()`:
      ! Supply unique named claim fields to correct; see `claim()`.

---

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = list(wording = "First",
        wording = "Second"), reason = "Clarify")
    Condition
      Error in `apply_assistant_proposal()`:
      ! Supply unique named claim fields to correct; see `claim()`.

---

    Code
      apply_assistant_proposal(x, p, "Reviewer", corrections = list(threshold = 3),
      reason = "Clarify")
    Condition
      Error in `apply_assistant_proposal()`:
      ! Set a numerical threshold through a new model proposal, not an interpretation correction.

# correction form distinguishes clearing a field from retaining it

    Code
      inquiry_corrections(values, proposed)
    Condition
      Error in `inquiry_corrections()`:
      ! The correction form is incomplete. Reopen the suggestion editor.

