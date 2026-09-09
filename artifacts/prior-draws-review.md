# Prior draw explorer verification

2026-09-09. Implemented the bounded two-condition prior explorer proposed in
`bayesian-draw-visualization-research.md`.

The workbench now offers Possible outcomes for retained numerical priors and
proposal previews. Each selected index uses the original aligned means, future
measurements, and contrasts. Plotting never resamples. Quantile dots use the
analytic Normal contrast distributions (100 representative quantiles, 1% mass
each); strict threshold probabilities remain analytic. Text identifies the
prior and seed and distinguishes population means from one future measurement
at each condition. Previous/next and a labeled slider provide manual control.

Verification includes draw identities, exact-mass approximation, point-mass
threshold behavior, fixed plot limits, preserved RNG state, independent panel
selection, and each step button's outgoing slider update. The browser check
caught and prompted a fix for a loop-closure event binding error.

`dev/verify-prior-draws.cjs` passed in Chrome against the actual local workbench
on port 3912: forward/back stepping, keyboard activation, returning to the
same realization, tab and resize stability, constant analytic probabilities,
both rendered plots, no visible Shiny errors or page exceptions, and no page
horizontal overflow at 390px. The mobile pair and dot screenshots were visually
inspected. Browser initialization waits for the initial density plot to render
before operating dynamically created navigation. The agent-browser CLI was
unavailable, so verification used the installed Playwright runtime.

R code was Air-formatted; focused Jarl and git diff whitespace checks passed.
The workbench guide and NEWS describe the feature; pkgdown was rebuilt.

This is prior exploration, not posterior evidence. No regression draw adapter
or animation was added. Human comprehension testing remains future validation;
a working UI alone does not establish that users understand these distinctions.

Final validation: `R CMD check --no-manual` completed with 0 errors, 0 warnings,
and 0 notes (`NOT_CRAN=true`; remote system-clock checking disabled). The final
focused prior visualization suite passed 30 assertions. Rebuilt documentation
passed browser checks on 11 pages at desktop/mobile widths, including 127 local
links/anchors, alternative text, search, keyboard skip link, and navigation.
