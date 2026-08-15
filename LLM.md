# Notes to self (LLM landing in the aeocha repo)

This repo is SUNSET (2026-08-15) and intentionally empty: no code, no tests,
no facade. Do not add anything here.

- The framework lives in the aether stdlib: `std.spec`, `std.os.testing`,
  `std.http.client.httptest`, `std.mutation`. Feature work, bug fixes, and
  asks all go to the aether repo.
- `README.md` here is the consumer migration guide (import mapping + rename
  recipe + the `contrib.aeocha` special case). Keep it accurate until the
  last known consumer migrates; that list is in the README.
- `deprecation_notice.md` is the historical narrative of the sunset
  (thinning → IPC retirement → std.mutation adoption → facade deletion).
  Append-only.
- Everything deleted (facade, tests, docs, mutation tool, asks, TODO) is in
  git history before commit tagged by the "tombstone" message, and its
  living descendants are in the aether tree.
- Once aeo, aether-ui, avn, fbs-core, aeci, and fight_flash_fraud no longer
  `import aeocha` (or `contrib.aeocha`), archive the GitHub repo.
