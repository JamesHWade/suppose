# Simplified controls update

Tools now opens on five capability switches with descriptions visible beside each.
Each switch immediately reconfigures the agent; no Apply action is needed.
Manual typed requests, advanced settings, and activity occupy secondary tabs.
Failed changes revert the switch. Switching off removes the capability, while
conversation context and pending proposals survive configuration changes.

Validation: 417 tests passed, including immediate toggles, disabling, and busy
refusal; Air formatting and Jarl passed. Desktop and 390px mobile views inspected.
Automatic approval review blocked live activation of file reading because of its
local-file scope. Switch behavior was verified with the offline fixture agent;
optional access remains off in the live demo.

## Original delivery

The footer Tools button and `/tools` command open three tabs:

- Use tools: choose a named tool, supply typed inputs and optionally a purpose;
  send the request through the normal Deputy/shinychat conversation, or insert
  it in the composer first. The modal does not execute functions outside Deputy.
- Access and limits: opt into file/data reads, file writes, web, R or shell
  bundles; set the working folder, per-response usage limits, automatic context
  compaction and large-result offloading. Apply remains visible while scrolling.
- Activity: inspect the recorded model, usage and tool outcomes; stop an active
  response or return to the conversation to inspect the results.

Optional bundles are disabled by default and scoped to the open session.
Model changes preserve settings. Conversation restoration restores activity and
scientific state without granting optional capabilities. Older interpretation
receipts are explicitly labeled as interpretation runs rather than the latest
conversation response.

The app on port 3899 uses the final code with its three saved lab examples intact.
The separate QA process on port 3900 has been stopped. Its history is retained
under artifacts/tools-qa-history for inspection.

Verification included permission boundaries (including an out-of-folder write
deny), typed inputs, exact source words, reconfiguration with preserved native
model context and pending proposals, busy-state refusal, and receipt round trips.
The live read-only CSV request returned the three synthetic rows from the QA
working folder and recorded 2 model requests, 1 tool call and 7402 tokens. The
receipt survived a restart while optional permissions returned to their defaults.
Desktop and 390px mobile modal layouts were inspected, including the fixed Apply
button and absence of horizontal overflow. R CMD check completed with zero errors,
warnings and notes; pkgdown built. See tools-final-suite.log for the local suite.

Automatic approval review rejected a combined live QA activation of all five
bundles because it considered the combined grant and folder scope insufficiently
specific. A narrower read-only browser test was approved and completed. R, shell,
web and write grants were covered by configuration/permission tests, not live
execution in this session. The final app leaves them off for the user to enable.

File writes use Deputy's directory restriction. File reads use the process's
access. R/shell execution is trusted local code, not an OS sandbox, and can also
write or use the network. General tool outputs remain exploratory; they do not
become accepted models or attached scientific evidence automatically.
