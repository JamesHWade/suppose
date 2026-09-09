# Lab conversations

These are fictional scientist conversations driven through the live Muse/Deputy
chat UI. All measurements, uncertainty ranges and scenarios were invented for
this demonstration. Each conversation contains three scientist turns and three
model replies, with tool attempts preserved.

- [Assay plate effects](http://127.0.0.1:3899/?shinychat_conversation_id=c_001a0806e02545384fd4af3): a reagent-lot suspicion becomes a narrower comparison of edge-to-center ratios under matched handling. The interpretation was reviewed and applied after a browser reload.
- [Polymer cure temperature](http://127.0.0.1:3899/?shinychat_conversation_id=c_001a08070f52b6399c97cfa): elicited mean-strength intervals produce a prior contrast and a predictive contrast. The numerical proposal remains pending for review. No measurements were imported or posterior fitted.
- [Spectrometer drift](http://127.0.0.1:3899/?shinychat_conversation_id=c_001a08073a7002498598aca): treatment order and reference drift motivate a better next-run comparison. The qualitative interpretation remains pending.

Open the app menu to find the native searchable conversation history. Open
**Record** to inspect the retained interpretation or pending suggestion. Rename
and delete are available through each conversation's action menu.

The responses are useful examples of clarification, not a scientific validation
of the model. In particular, the materials calculation needed repeated tool
calls to satisfy source-quotation checks; these were retained rather than edited
out. The drift conversation's claim that close-in-time comparisons “isolate” a
coating effect is too strong without randomization and control of specimen
properties; the final scientist turn explicitly introduces randomized blocks
and unresolved aging/re-positioning effects.

History is stored locally in `.suppose/conversations` and excluded from package
builds. It contains transcripts, native tool/UI history, developing records and
pending proposals. Manual editor drafts are not autosaved. The no-agent local
guide uses portable JSON export; automatic history requires the agent-backed
chat. This local shared directory is intended for one user.

To reopen after stopping the app, run `Rscript dev/run-lab-app.R` from the project
with the compatible development shinychat environment and configured local
OpenRouter credentials. The links use port 3899.

Verification: all 18 messages and three distinct initial claim identities were
checked from the native files. Pending proposals still pass application checks
on reconstructed records. A process restart restored the numerical proposal;
sidebar switches restored the applied assay and pending drift records. The
372 offline expectations passed, R CMD check had no errors/warnings/notes,
and pkgdown built successfully. Desktop and 390px mobile views were inspected.

The history adapter reduces stored tool error conditions to their messages so
R stack traces containing closures/pointers cannot break restoration. The one
affected fictional turn was repaired; its original JSONL is retained in the
artifacts directory. Every saved native turn was deserialized successfully after
the repair. The visible failed tool attempts and their messages remain present.
