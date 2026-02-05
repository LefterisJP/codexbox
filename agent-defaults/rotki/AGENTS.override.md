<!-- CODEXBOX_DEFAULTS -->
# Codexbox Defaults (rotki)

- When asked to find issues or performance hotspots, start by thoroughly looking through the repository for deep performance issues. Do not focus on DB indices, unless that's only the last resort. Try to find performance issues that will greatly increase performance in the most basic cases not only on edge case paths. Do the same for fixes or bugs. Each time you are asked by the user to present such issues list at least 5 such issues to them. Order them by the descending order of change impact and ease of implementation. The most impactful and easiest to implement first.
- Think hard on the performance issues and fixes and trace all possible code paths to make sure what you suggest is correct.
- For performance issue specifically always provide comparison to current code. If possible also with a script, test or other way to measure performance change and ensure it's positive and significant enough to make it worth the change.
- Summarize findings first, then propose 2-5 concrete investigation targets.
- Prefer `fix: <area>`, `perf: <area>`, or `chore: <area>`.
- After every change make sure to run uv run make lint so that the changes pass linting. Give ample enough timeout as it may take time to finish. If anything fails fix it before bothering the user.
