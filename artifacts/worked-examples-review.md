# Worked examples in the workbench

2026-09-09. Four guided records are available from the welcome screen, the
Examples toolbar button, and the Record drawer. The public
`suppose_worked_example()` constructor exposes the same records in R.

1. A fictional meetings question: original wording, a clarified revision,
   a bounded outcome and open assumptions, without a numerical model.
2. Invented strength judgments: independent and correlated prior revisions,
   linked possible outcomes, and mean versus future-measurement uncertainty.
3. Public PlantGrowth outcomes: an explicitly retrospective normal update,
   analyst-selected prior, fixed measurement SD, and retained sensitivity analysis.
4. Synthetic coating outcomes: baseline and extended regression reviews,
   residual checks, and exact leave-one-out comparison on the same rows.

Every example contains a saved walkthrough with inspection steps, a learning
exercise, and interpretation limits. Tutorial reviews identify their author;
they do not imply the user's approval. The gallery opens a new browser tab and
uses a separate session without automatic history storage. Save/download keeps
an edited example and its walkthrough. Existing record and unsaved editor state
stay in the original session. The save notice reflects the session's actual
storage configuration.

Validation:

- 68 focused assertions passed, including all record round trips, walkthrough
  persistence, source/assumption boundaries, baseline/extension results,
  preservation of RNG state, and separation from the supplied record/history.
- `dev/verify-worked-examples.cjs` passed through the actual app: all four gallery
  links, separate tabs, qualitative editing, linked draw stepping, saved
  update/sensitivity/regression plots, downloads, and retention of both the
  original question and unsaved editor text. No visible Shiny errors or browser
  exceptions, and no horizontal page overflow at 390px.
- Gallery and walkthrough screenshots were visually inspected on desktop and
  mobile. Browser assertions account for the record format's scalar arrays and
  target the opened regression result rather than a collapsed sibling.
- Air formatting, focused Jarl checks, and whitespace checks passed.
- Documentation rebuilt with the new reference entry and workbench guide.
  Browser verification passed on 11 pages and 129 local links/anchors, with
  search, keyboard navigation, image alternative text, and mobile navigation.

The walkthroughs teach currently supported workflows. These checks establish
functionality and provenance, not measured improvement in human comprehension.

Full package validation: 1,358 assertions passed with no skips. R CMD check
completed with 0 errors, 0 warnings, and 0 notes (`NOT_CRAN=true`; remote
system-clock checking disabled).
