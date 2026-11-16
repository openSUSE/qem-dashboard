# Security audits

The `security audits` workflow (`.github/workflows/audits.yml`) runs daily on
`main` and reports Perl (`cpanfile`) and npm (`package-lock.json`) advisories
that are not waived.

A pull request is gated separately by `.github/workflows/audit_diff.yml`. It
fails only on advisories the PR introduces, never on advisories already on
`main`.

## When an issue is opened

The nightly run opens or updates one issue per ecosystem, titled
`Security audit: unwaived <ecosystem> advisories on main`, labelled
`dependencies` and `security`. The issue is closed automatically by the first
clean nightly run.

## Triage

For each advisory listed in the issue, decide in this order:

1. **Fix.** A fixed version exists and we can require it. Raise the floor in
   `cpanfile`, or update `package.json` and `package-lock.json`. For Perl, check
   the openSUSE normalized version that qam2 runs (for example
   `perl-Cpanel-JSON-XS-4.800.0` is upstream `4.80`).
2. **Waive.** The advisory does not apply to us. Add one line to
   `.audit-waivers`:

   ```text
   <advisory-id> <expiry YYYY-MM-DD> <reason and link>
   ```

   Expiry is at most one year out. Each waiver states why the advisory does not
   apply. Waivers merge through a reviewed PR like any other change.

3. **Track.** No fix exists yet. Keep the issue open and record the ID and the
   date in `tasks/todo.md`.

After a fix or waiver merges, the next nightly run closes the issue on its own.

## Expired waivers

An expired waiver is reported again by the nightly run and by any PR that
touches the affected code. It does not block unrelated PRs.

## Running the checks locally

```sh
make check-audits-cpan   # Perl, waivers applied
make check-audits-npm    # npm, waivers applied
```

Local `cpan-audit` uses an older advisory database than CI. CI is authoritative.
