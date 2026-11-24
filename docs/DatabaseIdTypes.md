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

`openqa_jobs` reached 70% of the range in about two years because every
re-post of a known job burned one id. It was widened to `BIGINT` in migration
13 and the burning upsert was removed in `fix(jobs): avoid burning sequence
ids on re-posted jobs`.

## Measurements

Taken from a production dump of 2026-03-11 (schema version 12, before
migration 13):

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

## Decisions

- Only `openqa_jobs` needed a type change: it is `BIGINT` since migration 13,
  together with `job_remarks.openqa_job_id`.
- The remaining tables stay on `int4`. With the burning upserts removed, their
  sequences now grow with the row count instead of with every update, so the
  free range is spent on real rows only: `channels`, the closest to the limit,
  has 88% left after the 11.6% already consumed.
- Widen a column (and its sequence and referencing foreign keys) to `BIGINT`
  once a sequence passes 50% of its range. Widening is a table rewrite, so do
  it deliberately, not speculatively.

## Checking current utilisation

```sql
SELECT sequencename, last_value, max_value,
       round(100.0 * last_value / max_value, 2) AS pct_used
  FROM pg_sequences
 WHERE schemaname = current_schema()
 ORDER BY pct_used DESC;
```
