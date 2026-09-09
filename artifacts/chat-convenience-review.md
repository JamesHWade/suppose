# Chat configuration convenience

9 September 2026. `suppose_app()` and `suppose_example_app()` now accept either
an ellmer Chat object or a zero-argument constructor through the named `chat`
argument. Existing positional arguments and the `chat_factory` compatibility
argument remain supported. `agent_factory` is the advanced route for configuring
Deputy execution, permissions, and usage limits.

An object supplies provider and Model configuration, captured at app creation.
Each session reconstructs a fresh ellmer Chat through the public configuration
API. History, system prompts, tools, callbacks, and conversation IDs are not
imported from the object. The caller's object is not modified. A constructor
instead creates the fresh session object, retaining custom subclass behavior
and allowing session-specific resources. Constructors must return a new Chat
per call. All connected inquiry sessions still use a Suppose Deputy Agent.

This uses the public ellmer 0.5.0 Chat and Model APIs; the minimum suggested ellmer
version and a runtime check make that dependency explicit. See the upstream
[Chat API](https://ellmer.tidyverse.org/reference/Chat.html).

Verification:

- Unit coverage checks isolation, original-object preservation, configuration
  capture, tools/history reset, deferred constructors, public app wiring across
  sessions, and conflicting or invalid arguments.
- 104 focused assertions passed without warnings or skips.
- Actual requests through the local scripted model server preserved provider
  configuration, kept histories separate, and did not inherit a source callback.
  The original callback remained functional on the original chat.
- R CMD check with NOT_CRAN=true: 1,301 assertions, no skips, 0 errors, 0 warnings,
  and 0 notes.
- Documentation rebuilt; 11 reader routes and 126 local links/anchors pass the
  browser checks. The setup guide teaches object and constructor forms first.
- Air formatting and focused Jarl lint pass. Generated error snapshots retain
  testthat's standard trailing blank line.
