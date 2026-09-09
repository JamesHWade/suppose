# the first-session example exposes an assumption and a challenge

    Code
      print(x)
    Message
      
      -- Cure temperature and strength --
      
      Revision 1 (draft): Initial claim
      Revision 2 (proposed): Inspect independent mean uncertainty
      Revision 3 (accepted): Shared uncertainty may move both means together
      
      -- Current interpretation 
      Higher cure temperature makes the material stronger.
      Target: Mean batch strength at 160 degC minus mean batch strength at 140 degC
      Scope: Formulation F; protocol P; fixed cure duration; independently prepared
      batches
      Units: MPa
      Assumptions: Comparable preparation and measurement protocols
      Open questions: A causal interpretation needs a justified intervention
      protocol.

---

    Code
      print(x$revisions[[3]]$prediction)
    Message
      
      -- Prior consequences --
      
      Mean difference: 8 MPa; central 90% interval [3.76, 12.24].
      P(mean difference > 5 MPa | model and prior) = 0.878
      Simulated outcomes, not observations. Seed: 47.

