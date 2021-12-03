-- 1 up
CREATE TABLE IF NOT EXISTS channels (
    id       SERIAL PRIMARY KEY,
    name     TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS incidents (
  id         SERIAL PRIMARY KEY,
  number     INT NOT NULL,
  rr_number  INT DEFAULT 0,
  project    TEXT,
  review     BOOLEAN DEFAULT FALSE,
  review_qam BOOLEAN DEFAULT FALSE,
  approved   BOOLEAN DEFAULT FALSE,
  emu        BOOLEAN DEFAULT FALSE,
  active     BOOLEAN DEFAULT FALSE,
  packages   TEXT[] NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS incident_channels (
    id       SERIAL PRIMARY KEY,
    incident INT NOT NULL REFERENCES incidents(id),
    channel  INT NOT NULL REFERENCES channels(id),
    revision INT
);
CREATE TABLE IF NOT EXISTS incident_openqa_settings (
  id       SERIAL PRIMARY KEY,
  incident INT NOT NULL REFERENCES incidents(id),
  version  TEXT NOT NULL,
  flavor   TEXT NOT NULL,
  arch     TEXT NOT NULL,
  settings JSONB CHECK(JSONB_TYPEOF(settings) = 'object') NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS update_openqa_settings (
  id       SERIAL PRIMARY KEY,
  product  TEXT NOT NULL,
  arch     TEXT NOT NULL,
  build    TEXT NOT NULL,
  repohash TEXT NOT NULL,
  settings JSONB CHECK(JSONB_TYPEOF(settings) = 'object') NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS incident_in_update (
  id       SERIAL PRIMARY KEY,
  settings INT REFERENCES update_openqa_settings(id),
  incident INT REFERENCES incidents(id)
);
CREATE TYPE qa_status AS ENUM ('unknown', 'waiting', 'passed', 'failed', 'stopped');
CREATE TABLE IF NOT EXISTS openqa_jobs (
  id                SERIAL PRIMARY KEY,
  update_settings   INT REFERENCES update_openqa_settings(id),
  incident_settings INT REFERENCES incident_openqa_settings(id),
  name              TEXT NOT NULL,
  job_group         TEXT NOT NULL,
  status            qa_status NOT NULL DEFAULT 'waiting',
  job_id            INT NOT NULL,
  group_id          INT NOT NULL,
  distri            TEXT NOT NULL,
  flavor            TEXT NOT NULL,
  arch              TEXT NOT NULL,
  version           TEXT NOT NULL,
  build             TEXT NOT NULL,
  updated           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ON channels(name);
CREATE UNIQUE INDEX ON incidents(number);
CREATE INDEX ON incidents(active);
CREATE UNIQUE INDEX ON incident_channels(incident, channel);
CREATE UNIQUE INDEX ON incident_openqa_settings(incident, version, flavor, arch);
CREATE UNIQUE INDEX ON update_openqa_settings(product, arch, build);
CREATE UNIQUE INDEX ON openqa_jobs(job_id);
CREATE UNIQUE INDEX ON openqa_jobs(distri, flavor, arch, version, build, name);
CREATE INDEX ON openqa_jobs(job_group);
CREATE INDEX ON openqa_jobs(updated);
CREATE INDEX ON openqa_jobs(incident_settings);
CREATE INDEX ON openqa_jobs(update_settings);
CREATE INDEX ON incident_in_update(incident);
CREATE INDEX ON incident_in_update(settings);

-- 1 down
DROP TABLE IF EXISTS openqa_jobs;
DROP TABLE IF EXISTS incident_in_update;
DROP TABLE IF EXISTS update_openqa_settings;
DROP TABLE IF EXISTS incident_openqa_settings;
DROP TABLE IF EXISTS incident_channels;
DROP TABLE IF EXISTS incidents;
DROP TABLE IF EXISTS channels;

-- 2 up
ALTER TABLE incident_openqa_settings ADD COLUMN with_aggregate BOOLEAN DEFAULT FALSE;
