# Database id types

Review of the `int4` id and sequence types in `migrations/dashboard.sql`,
triggered by the `openqa_jobs` sequence exhaustion described in
<https://progress.opensuse.org/issues/210741>.

## Why ids run out

Every `SERIAL` column draws from an `int4` sequence capped at 2,147,483,647.
PostgreSQL evaluates the `nextval()` default before a conflict is detected, so
`INSERT ... ON CONFLICT DO NOTHING|UPDATE` on an already existing row burns an
id and returns without storing anything. The sequences therefore grow with the
number of upsert _attempts_, not with the number of rows.

`openqa_jobs` came within 0.2% of the limit because every re-post of a known job
burned an id. It was widened to `BIGINT` in migration 13 and the burning upsert
was removed in `fix(jobs): avoid burning sequence ids on re-posted jobs`.

## Baseline check of 2026-03-11

Taken from a production dump taken on 2026-03-11 (schema version 12, before
migration 13); the dump itself is not part of this repository:

| table                    | rows      | sequence last_value | range used | ids per row |
| ------------------------ | --------- | ------------------- | ---------- | ----------- |
| openqa_jobs              | 2,778,034 | 1,505,662,168       | 70.1%      | 542         |
| channels                 | 6,870     | 249,027,621         | 11.6%      | 36,250      |
| incident_channels        | 123,265   | 249,027,621         | 11.6%      | 2,020       |
| incidents                | 11,066    | 19,060,321          | 0.9%       | 1,722       |
| incident_in_update       | 1,512,834 | 4,961,264           | 0.2%       | 3.3         |
| incident_openqa_settings | 156,625   | 2,349,873           | 0.1%       | 15          |
| update_openqa_settings   | 195,937   | 221,521             | 0.01%      | 1.1         |
| job_remarks              | 1,505     | 137,871             | 0.006%     | 92          |

Other `int4` columns have no measured pressure: `openqa_jobs.job_id` peaks at
21,305,690 (openQA o3 allocates roughly 2M job ids per year),
`openqa_jobs.group_id` at 699 and `incidents.number` at 331,922 (Redmine ids).

## Production check of 2026-11-26

Read of the running instance with schema version 13, using `pg_sequences` for
the sequences and `pg_stat_user_tables.n_live_tup` for the row counts;
`n_live_tup` is a stats-collector estimate, so the row counts are approximate:

| table                    | rows      | sequence last_value | range used | ids per row |
| ------------------------ | --------- | ------------------- | ---------- | ----------- |
| openqa_jobs              | 4,449,945 | 2,143,121,954       | n/a        | 482         |
| channels                 | 29,810    | 299,388,962         | 13.9%      | 10,043      |
| incident_channels        | 198,863   | 299,388,962         | 13.9%      | 1,505       |
| incidents                | 19,377    | 24,043,577          | 1.1%       | 1,241       |
| incident_in_update       | 2,371,511 | 6,283,902           | 0.3%       | 2.6         |
| incident_openqa_settings | 302,019   | 2,576,645           | 0.1%       | 8.5         |
| update_openqa_settings   | 228,864   | 258,184             | 0.01%      | 1.1         |
| job_remarks              | 7,499     | 273,382             | 0.01%      | 36.5        |

The `int4` range no longer applies to `openqa_jobs`: its sequence is `int8` by
now, so `pg_sequences` reports `max_value` 9,223,372,036,854,775,807 and a
`pct_used` that rounds to 0.00.

The 2026-11-26 read ran at 14:52. A second read on 2026-11-25 10:18 sampled
four sequences: `openqa_jobs` 2,143,108,335, `channels` 298,951,787,
`incidents` 23,997,163 and `job_remarks` 272,555. The remaining tables have no
sample from that day. `channels` and `incident_channels` burn in lockstep,
because every incident sync probes both tables once per channel, so their
sequences read identically in both measurements and the `channels` sample
covers both.

| table                       | ids per year, 03-11 to 11-26 | ids per year, 11-25 to 11-26 |
| --------------------------- | ---------------------------- | ---------------------------- |
| openqa_jobs                 | 895M                         | 4.2M                         |
| channels, incident_channels | 71M                          | 134M                         |
| incidents                   | 7.0M                         | 14.2M                        |
| job_remarks                 | 0.19M                        | 0.25M                        |
| incident_in_update          | 1.9M                         | n/a                          |
| incident_openqa_settings    | 0.3M                         | n/a                          |
| update_openqa_settings      | 0.05M                        | n/a                          |

Had `openqa_jobs` stayed on `int4`, it would have had 4,361,693 ids left on
2026-11-26, less than two days at the 260-day average of 895M ids per year.
Since migration 13 and the re-post fix it grows in the same order as the row
count: 4.2M ids per year in the 28-hour sample, against 2.3M rows per year.

Every table except `update_openqa_settings` still burns faster than its row
growth, because the upsert change of
<https://github.com/openSUSE/qem-dashboard/pull/3480> is not deployed yet. At
the 28-hour rate `channels` has about 14 years left and `incidents` about 150.
Once it is deployed they advance only when a row is created, so the sequences
follow the row counts instead of the update volume.

## Decisions

- Only `openqa_jobs` needed a type change: it is `BIGINT` since migration 13,
  together with `job_remarks.openqa_job_id`.
- The remaining tables stay on `int4`. The 2026-11-26 check puts the worst one,
  `channels`, at 13.9% used; once PR #3480 is deployed the free range is spent
  on real rows only.
- Widen a column (and its sequence and referencing foreign keys) to `BIGINT`
  once a sequence passes 50% of its range. Widening is a table rewrite, so do
  it deliberately, not speculatively.

## Checking the live database

The 2026-11-26 point came from the running instance, the baseline from a stored
dump. Repeat the check with a maintainer account that can read the sequences;
both statements are read-only and need no privileges beyond `SELECT` on
`pg_sequences` and `pg_stat_user_tables`:

```sql
SELECT sequencename, last_value, max_value,
       round(100.0 * last_value / max_value, 2) AS pct_used
  FROM pg_sequences
 WHERE schemaname = current_schema()
 ORDER BY pct_used DESC;

SELECT relname, n_live_tup AS rows
  FROM pg_stat_user_tables
 WHERE schemaname = current_schema()
 ORDER BY relname;
```
