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
      records/<id>/record.json     a record bundle (write_record())
      records/<id>/meta.json       title, digest, state revision
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
- A project with no record gets one from this turn's typed words (or the
  latest typed), titled "My inquiry", authored by the host's user id. Every
  word must say where it came from; an item without `via` is refused.
- A turn keeps every word it was given across its calls, with times, so a
  draft's provenance holds the words its quotes came from.
- Staged changes are rebuilt with their text lists restored (JSON returns an
  explicitly cleared list as `list()`), and each form starts from the latest
  current draft of it, so a follow-up keeps the settings it leaves out.
- Arguments arriving as JSON take the types each tool declares.
- A new draft replaces only the drafts of its kind that were there before its
  turn began; one another tab published meanwhile stays beside it.
- A turn the host reports before Suppose saw it is recorded as settled, so a
  later call cannot start it, and a turn whose drafts cannot be finished is
  recorded as failed rather than left running.
- The record's state revision rises whenever its content changes, which its
  revision count does not do for attached data, fits or frozen tests.

## SC-5: the state document (built)

`R/host-state.R`. `host_state()` builds `suppose/state@1` for a tab: the open
record, the project's other records (at most 20), the claim's fields (400
characters each), the review status, the conversation's pending drafts (at
most 8, ready or still being written), the pane's open form, retained counts,
the latest fit and design, open tests soonest first, the last decision,
one-line method limitations, whether quotes are host-verified, and the
approval sentence. Lists shrink until the document fits 6,000 characters of
indented JSON, and every capped list carries a count of what it left out.
The document's `revision` is one sequence per conversation that rises
whenever a tab's document changes. `host_state_text()` is its one line, and
`host_read_inquiry(section, page)` reads one section at a time, `pending`
and `records` included. On the four worked examples the document is 1,900 to
2,400 characters; the workbench's own summary of the same records is 2,741
to 7,996.

## Not built

- SC-3, the embedded layout; SC-4, the MCP entry point that registers these
  functions as `suppose_*` tools and the `turn-settled` host call.
- SC-6: locking and compare-and-swap on record digests for records shared by
  several tabs or conversations; one process serves a store until then.
- Applying, declining and accepting drafts from the pane.
