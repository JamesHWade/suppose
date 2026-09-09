# Native conversation interactions

Model-written next-step suggestions use shinychat's native suggestion/submit
markup. Most substantive responses are prompted to offer two or three distinct
next steps; brief acknowledgments and closing replies may omit them. Clicking
sends the displayed prompt. No second model request or canned suggestion generator
is used. Cards can offer exploration or preferences without inventing observations.

Interpretation tools return native ContentToolResult display metadata, with a
Shiny output inside the rich tool card. The model still receives the same result
text. After a response finishes, the card offers Apply interpretation, Correct,
and Decline. Review details show the complete final draft and source attribution.
The server validates the current request and record before acting. Applied and
declined states persist. Older drafts cannot operate on newer proposals, and
changing conversations invalidates controls from the previous conversation.
Applying creates a revision; formal acceptance remains the existing separate
record review. General optional tools retain their native Deputy display.

The shared installed shinychat build initially emitted legacy custom-element
markup that was invisible in the current frontend. A clean installation from
posit-dev/shinychat at eb024589465f5227405d567854b96cc87e5bb9ac restored native
structured tool rendering and history. First verified in a project-local library,
then installed in /Users/james/Library/R/arm64/4.6/library at the user's request.
The demo launchers now use the main R library.

Sources inspected:
- https://posit-dev.github.io/shinychat/r/articles/get-started.html
- https://posit-dev.github.io/shinychat/r/articles/tool-ui.html
- Development R transport, HistoryController, tool-result display, and frontend
  suggestion/tool rendering at the verified revision.

Verification:
- Full suite: 436 passing tests; focused tests cover applying, declining, stale
  and repeated clicks, current-record integrity, and restoring decision state.
- R CMD check: no errors or warnings; one environment note because the remote
  clock could not be reached. Air and Jarl passed on changed R code.
- Live fictional conversation: native inline review card and two suggestions;
  clicking a suggestion sent the exact prompt and produced three new suggestions.
- Process restart restored the pending review controls and all five suggestions.
- Mobile viewport 390px: no horizontal overflow. Desktop and mobile reviewed.
- Existing three saved lab conversations were audited without changing their
  records. See chat-cards-preserved-history.log.

Automatic approval review rejected clicking Apply on the fictional QA draft,
reasoning that the synthetic prompt requested review rather than application.
No live application or acceptance was performed. The underlying action and
stale-control behavior were verified in automated tests.

The QA conversation is retained under artifacts/cards-qa-history:
c_001a080b06ad46201b89dd1. Screenshots: chat-decision-mobile.png and
chat-decision-desktop.png. The primary demo is on port 3899.
