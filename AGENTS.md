# qem-dashboard Agent Guidelines

Full-stack web app for QEM workflow. Backend: Perl (Mojolicious), PostgreSQL.
Frontend: Vue.js 3, Sass, Vite.

## Build & Test Commands

- `make install-deps-cpanm`: Install Perl dependencies.
- `npm install && npm run build`: Install and build frontend.
- `make start-postgres`: Start PostgreSQL container.
- `script/dashboard daemon`: Start development server.
- `make tidy`: Perl formatting (perltidy).
- `npm run lint`: JS/Vue linting.
- `make test`: Run all tests.
- `make test-coverage`: Run tests with coverage (100% required).

## SPA Routing

When modifying routes in `assets/router.js`, also update catch-all route in
`lib/Dashboard.pm`.

## Constraints

- `tasks/`: Read/write for planning. Never run git operations on this
  directory.
- **Clean Tests:** Ensure `make test` output is clean. Extraneous log messages
  (e.g., Mojolicious info/debug logs) should be suppressed or asserted to
  maintain a clear signal-to-noise ratio.
- Do not commit anything from untracked folders, in particular tasks/
- Never run git clean or any command that deletes unversioned files. Ask for
  confirmation.
- **Commits:** Follow standard git commit message conventions (clear subject
  line, descriptive body). ALWAYS commit your changes in small, logical, and
  atomic increments before marking a task as complete. Each commit should
  represent a single, self-contained change that is easy to review. Avoid
  using "and" in commit titles; if a change requires "and", it should be split
  into multiple atomic commits.
- **Coverage:** EVERY change must maintain or achieve 100% statement coverage
  for backend files. Run `make test-coverage` to verify this. Tasks are only
  considered complete once full coverage is confirmed and all tests pass.
- **Perl:** Use `perltidy` with the provided `.perltidyrc`. Follow Mojolicious
  idiomatic patterns (signatures, helpers).
