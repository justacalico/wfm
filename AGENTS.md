WFM is a self-hosted web film manager for schools: a Rust/axum backend, a
Flutter web management UI, FilmCraft for in-browser editing, and FFmpeg for
rendering. The source of truth is GitLab; GitHub is a mirror that runs builds.

- Keep 100% Dart line coverage. Run `flutter test --coverage` before finishing
  and check coverage/lcov.info has no uncovered lines.
- Golden tests live in test/golden_test.dart; regenerate with
  `flutter test --update-goldens` and commit the PNGs.
- All user-facing strings go through lib/l10n/*.arb (en, en_GB, zh, ru, ga).
  Never hardcode strings in the UI. The landing page has its own ARB set.
- Every network call is injected (Api client, UpdateChecker, ReleaseFetcher)
  so tests never hit the real network.
- Server tests: `cd server && cargo test`. Migrations are plain SQL under
  server/migrations/<dialect>/.
- Commits follow Conventional Commits; `cog check` must stay clean.
- The landing page is a separate Flutter web app in landing/.
- Releases are managed by cocogitto. Never edit the version in pubspec.yaml
  by hand.
