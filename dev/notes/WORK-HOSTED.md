# Hosted inquiry: a store and turns driven by a host

September 30, 2026. Crucible's scoping note (its `docs/scope-suppose.md`,
stories SC-1 to SC-11) proposes Suppose's record drawer as an MCP App pane in
Crucible, with the conversation staying Crucible's. This note records what
is built and what is not.

## SC-2: the hosted adapter (built)

`R/host-store.R` and `R/host-turn.R`. A host names the person, project,
conversation, browser tab (`session`) and turn on every call, and supplies the
scientist's words: what they typed, suggestions they clicked, and answers to
the host's questions (`via`). Nothing lives in a Shiny session:

    <dir>/users/<user>/<project>/
      records/<id>.json            a record bundle (write_record())
      records/<id>.meta.json       title, digest, state revision
      conversations/<conversation>/
        state.json                 open record per tab, last opened, revisions
        turns/<turn>.json          what a turn staged, and how it ended
        drafts/<id>.json           drafts ready for review

- `host_call_tool()` begins the turn on its first call, rebuilds a
  `new_proposal_session()` from the store, runs one of the assistant's
  inquiry tools unchanged (the quote checks run on the host's words), and
  writes back what the tool staged. A turn keeps the record open in its tab
  at its first call.
- `host_settle_turn()` records the host's report: `done` publishes the drafts
  (replacing the earlier draft of the same kind on the record), `stopped`
  and `failed` publish nothing. A draft is never ready before its turn is
  done.
- A turn that never reports stays unfinished. A later turn from the same tab
  cancels it; a turn from another tab never does. `host_discard_turn()` is
  the scientist's way to drop one.
- A project with no record gets one from the first typed words, titled
  "My inquiry", authored by the host's user id.
- The record's state revision rises whenever its content changes, which its
  revision count does not do for attached data, fits or frozen tests.

## Not built

- SC-5, the bounded state document and `read_inquiry` by section.
- SC-3, the embedded layout; SC-4, the MCP entry point that registers these
  functions as `suppose_*` tools and the `turn-settled` host call.
- SC-6: locking and compare-and-swap on record digests for records shared by
  several tabs or conversations; one process serves a store until then.
- Applying, declining and accepting drafts from the pane.
