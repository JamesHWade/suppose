# Development dependency update

September 9, 2026. Installed in `.suppose/runtime-library`, which the local app
loads before the user library:

- ellmer 0.5.0.9000: tidyverse/ellmer@92cfa7f48270048105ea1bfb44d23a2e59c2df6e
- shinychat 0.4.0.9000: posit-dev/shinychat/pkg-r@dde163ea6b27099304a658f3649dd1fac98208bd

Both revisions matched upstream HEAD when installed. Required dependencies were
resolved by pak. The system/user library installations were not replaced.

App construction succeeded. Focused inquiry, host, controls and chat-card tests:
154 assertions, zero failures, warnings or skips. This is a focused compatibility
check, not a repeat of the entire P0 browser suite or a promise of compatibility
with every future ellmer release. The construction check emitted a sandbox cache
write warning; the restarted app runs with access to that cache.

See `dev-dependencies-install.log` and `dev-dependencies-verification.log`.
