# the CLI exposes qualitative meaning and refuses invented predictions

    Code
      print(x)
    Message
      
      -- untitled --
      
      Revision 1 (accepted): Initial claim
      
      -- Current interpretation 
      If three teams say yes, would that establish demand?
      Open questions: What would count as a paid commitment?

---

    Code
      Rapp::run(script, c("predict", path, "--seed", "47"))
    Condition
      Error:
      ! This record has no numerical candidate. Use inspect to read its qualitative interpretation.

# CLI measurements retain provenance and refuse double import

    Code
      Rapp::run(script, args)
    Condition
      Error in `validate_evidence()`:
      ! These source/observation IDs are already attached. Reusing them under a new role or conversion would count the same information twice.

