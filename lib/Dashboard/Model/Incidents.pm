# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Model::Incidents;
use Mojo::Base -base, -signatures;

has [qw(log pg)];

sub blocked ($self) {
  my $incidents = $self->pg->db->query(
    "SELECT * FROM incidents
     WHERE active = TRUE AND approved = FALSE AND review_qam = TRUE AND (rr_number IS NOT NULL OR type = 'git')
     ORDER BY number"
  )->hashes->to_array;

  $self->_map($_) for @$incidents;

  return [
    map {
      {
        incident         => $_,
        incident_results => $self->_incident_openqa_jobs($_),
        update_results   => $self->_update_openqa_jobs($_)
      }
    } @$incidents
  ];
}

sub build_nr ($self, $inc) {
  return undef
    unless my $settings = $self->pg->db->query(
    'SELECT build FROM incident_openqa_settings ios JOIN openqa_jobs oj ON oj.incident_settings = ios.id
     WHERE incident = ?
     ORDER BY updated DESC
     LIMIT 1', $inc->{id}
    )->hash;
  return $settings->{build};
}

sub find ($self, $options = {}) {
  my $incidents = $self->pg->db->query(
    'SELECT number, project, packages, rr_number, review, review_qam, approved, emu, active, embargoed, priority, ARRAY_AGG(c.name) as channels,
            scminfo, url, type
     FROM incidents i INNER JOIN incident_channels ic ON ic.incident = i.id INNER JOIN channels c ON ic.channel = c.id
     WHERE number = COALESCE(?, number) AND active = TRUE
     GROUP BY number, project, packages, rr_number, review, review_qam, approved, emu, active, embargoed, priority, scminfo, url, type
     ORDER BY number', $options->{number}
  )->hashes->to_array;
  $self->_map($_) for @$incidents;

  return $incidents;
}

sub openqa_summary_only_aggregates ($self, $inc) {
  my $res = $self->pg->db->query(
    'SELECT uos.id, uos.build, uos.settings
     FROM update_openqa_settings uos JOIN incident_in_update iu 
     ON uos.id=iu.settings WHERE incident=?', $inc->{id}
  )->expand->hashes;
  my %jobs;

  for my $settings (@$res) {
    if (!$jobs{$settings->{build}}) {
      $jobs{$settings->{build}} = [];
    }

    my $jobs_results = $self->pg->db->query(
      'SELECT arch,build,distri,flavor,group_id,job_group,job_id,name,status,version 
       FROM openqa_jobs WHERE update_settings=?', $settings->{id}
    )->hashes->to_array;
    push(@{$jobs{$settings->{build}}}, @$jobs_results);
  }
  return \%jobs;
}

sub openqa_summary_only_incident ($self, $inc) {
  my $res = $self->pg->db->query(
    'SELECT oj.status, count(oj.id)
     FROM incident_openqa_settings ios JOIN openqa_jobs oj ON oj.incident_settings=ios.id
     WHERE incident = ? AND oj.obsolete = false
     GROUP BY oj.status', $inc->{id}
  )->hashes;
  return {map { $_->{status} => $_->{count} } $res->each};
}

sub incident_for_number ($self, $number) {
  my $incident = $self->pg->db->query('select * from incidents where number = ? limit 1', $number)->hash;
  return $self->_map($incident);
}

sub number_for_id ($self, $id) {
  return undef unless my $array = $self->pg->db->query('select number from incidents where id = ? limit 1', $id)->array;
  return $array->[0];
}

sub id_for_number ($self, $number) {
  return undef
    unless my $array = $self->pg->db->query('select id from incidents where number = ? limit 1', $number)->array;
  return $array->[0];
}

sub name ($self, $inc) {
  my $number   = $inc->{number};
  my $packages = $inc->{packages} // [];
  my $package  = $packages->[0]   // 'unknown';
  return "$number:$package";
}

sub repos ($self) {
  my %titles;
  my $db  = $self->pg->db;
  my $res = $db->query('SELECT DISTINCT product, arch FROM update_openqa_settings ORDER BY product, arch')->hashes;
  for my $row ($res->each) {
    my $ids = $db->query(
      'SELECT id, build FROM update_openqa_settings
       WHERE product = ? AND arch = ? ORDER BY id DESC LIMIT 7', $row->{product}, $row->{arch}
    )->hashes;

    my $incidents;
    for my $id ($ids->each) {
      next unless my $example = $db->query(
        'SELECT group_id, distri, flavor, version FROM openqa_jobs
         WHERE update_settings = ? LIMIT 1', $id->{id}
      )->hash;

      # only calculate for the latest build
      $incidents ||= my $incs = $db->query(
        'SELECT i.number, i.id, i.packages FROM incidents i JOIN incident_in_update iu ON iu.incident = i.id
           WHERE settings = ? ORDER BY i.number', $id->{id}
      )->hashes->to_array;

      my %summary;
      my $jobs = $db->query(
        'SELECT status, COUNT(status) FROM openqa_jobs
         WHERE update_settings = ? GROUP BY status', $id->{id}
      )->hashes;
      for my $job ($jobs->each) {
        $summary{$job->{status}} = $job->{count};
      }
      $summary{linkinfo} = {
        distri  => $example->{distri},
        version => $example->{version},
        build   => $id->{build},
        groupid => $example->{group_id},
        arch    => $row->{arch},
        flavor  => $example->{flavor}
      };
      $summary{name} = $id->{build};

      my $title = "$example->{flavor}-$example->{version}-$row->{arch}";
      $titles{$title} ||= {summaries => [], incidents => $incidents};
      push(@{$titles{$title}{summaries}}, \%summary);
    }
  }

  return \%titles;
}

sub sync ($self, $incidents, $types = []) {
  push @$types, '', 'smelt' unless @$types;
  my $db = $self->pg->db;
  my $tx = $db->begin;

  $db->update(incidents => {active => 0}, {type => {'=' => $types}});
  for my $incident (@$incidents) { $self->_update($db, $incident) }

  $tx->commit;
}

sub update ($self, $incident) {
  my $db = $self->pg->db;
  my $tx = $db->begin;

  $self->_update($db, $incident);

  $tx->commit;
}

sub _group_nick ($group) {
  $group =~ s/ Incidents$//;
  $group =~ s/ Updates$//;
  $group =~ s/^Maintenance: //;
  return $group;
}

sub _incident_openqa_jobs ($self, $inc) {
  my $db      = $self->pg->db;
  my $inc_id  = $inc->{id};
  my $inc_nr  = $inc->{number};
  my $results = $db->query(
    "WITH openqa_status_for_incident AS (
     SELECT
         oj.id AS openqa_job_id,
         CASE
             WHEN (SELECT COUNT(jr.id) FROM job_remarks jr WHERE jr.openqa_job_id = oj.id AND jr.incident_id = ? AND jr.text = 'acceptable_for' LIMIT 1) > 0
             THEN 'passed'
             ELSE oj.status
         END AS incident_status
     FROM openqa_jobs oj
     )
     SELECT
         oj.job_group,
         oj.group_id,
         osfi.incident_status,
         COUNT(osfi.incident_status) AS incident_status_job_count
     FROM
         incident_openqa_settings os
         JOIN openqa_jobs oj ON oj.incident_settings = os.id
         JOIN openqa_status_for_incident osfi ON oj.id = osfi.openqa_job_id
     WHERE
         os.incident = ? AND oj.obsolete = false
         AND (oj.build !~ ':[0-9]+:' OR oj.build ~ (':' || ? || ':'))
     GROUP BY
         oj.job_group,
         oj.group_id,
         osfi.incident_status", $inc_id, $inc_id, $inc_nr
  )->hashes;
  my %ret;
  for my $result ($results->each) {
    my $id = $result->{group_id};
    $ret{$id} ||= {linkinfo => $result->{group_id}, name => _group_nick($result->{job_group})};
    $ret{$id}{$result->{incident_status}} = $result->{incident_status_job_count};
  }

  for my $id (keys %ret) {
    my $settings = $db->query(
      'SELECT settings
       FROM openqa_jobs oj JOIN incident_openqa_settings os ON oj.incident_settings = os.id
       WHERE oj.group_id = ? AND os.incident = ? ORDER BY oj.job_id DESC LIMIT 1', $id, $inc_id
    )->expand->hash->{settings};
    $ret{$id}{linkinfo} = {distri => 'sle', groupid => $id, build => $settings->{BUILD}};
  }

  return \%ret;
}

sub _update_openqa_jobs ($self, $inc) {
  my $db     = $self->pg->db;
  my $inc_id = $inc->{id};
  my $inc_nr = $inc->{number};
  my $ids
    = $db->query('SELECT settings FROM incident_in_update WHERE incident = ?', $inc_id)->arrays->flatten->to_array;

  my $results = $db->query(
    "WITH openqa_status_for_incident AS (
     SELECT
         oj.id AS openqa_job_id,
         CASE
             WHEN (SELECT COUNT(jr.id) FROM job_remarks jr WHERE jr.openqa_job_id = oj.id AND jr.incident_id = ? AND jr.text = 'acceptable_for' LIMIT 1) > 0
             THEN 'passed'
             ELSE oj.status
         END AS incident_status
     FROM openqa_jobs oj
     )
     SELECT
         oj.job_group,
         oj.group_id,
         us.build,
         oj.distri,
         oj.flavor,
         oj.arch,
         oj.version,
         osfi.incident_status,
         COUNT(osfi.incident_status) AS incident_status_job_count
     FROM
         update_openqa_settings us
         JOIN openqa_jobs oj ON oj.update_settings = us.id
         JOIN openqa_status_for_incident osfi ON oj.id = osfi.openqa_job_id
     WHERE
         us.id = ANY (?) AND oj.obsolete = false
         AND (oj.build !~ ':[0-9]+:' OR oj.build ~ (':' || ? || ':'))
     GROUP BY
         oj.job_group,
         oj.group_id,
         us.build,
         oj.distri,
         oj.flavor,
         oj.arch,
         oj.version,
         osfi.incident_status", $inc_id, $ids, $inc_nr
  )->hashes;
  my %ret;
  for my $result ($results->each) {
    my $id = "$result->{group_id} $result->{flavor} $result->{version}";
    $ret{$id} ||= {
      linkinfo => {
        distri  => $result->{distri},
        groupid => $result->{group_id},
        flavor  => $result->{flavor},
        version => $result->{version}
      },
      name => _group_nick($result->{job_group})
    };
    $ret{$id}{builds}{$result->{build}}{$result->{incident_status}} = $result->{incident_status_job_count};
  }

  for my $id (keys %ret) {
    my $result = $ret{$id};
    my $builds = delete $result->{builds};
    $result->{linkinfo}{build} = my $latest = (sort keys %$builds)[-1];
    my $build = $builds->{$latest};
    @{$result}{keys %$build} = values %$build;
  }

  return \%ret;
}

sub _update ($self, $db, $incident) {
  $db->query('INSERT INTO incidents (number, project) VALUES (?, ?) ON CONFLICT DO NOTHING',
    $incident->{number}, $incident->{project});
  my $row = $db->query('SELECT id, rr_number FROM incidents WHERE number = ? LIMIT 1', $incident->{number})->hash;
  my ($id, $rr_number) = ($row->{id}, $row->{rr_number} // 0);

  $db->query(
    'UPDATE incidents SET packages = ?, rr_number = ?, review = ?, review_qam = ?, approved = ?, emu = ?, active = ?,
       embargoed = ?, priority = ?, scminfo = ?, url = ?, type = ? WHERE id = ?', $incident->{packages},
    $incident->{rr_number}, $incident->{inReview}, $incident->{inReviewQAM}, $incident->{approved}, $incident->{emu},
    $incident->{isActive}, $incident->{embargoed}, $incident->{priority}, $incident->{scminfo} // '',
    $incident->{url} // '', $incident->{type} // '', $id
  );

  # Remove old jobs after release request number changed (because incidents might be reused)
  if (defined $incident->{rr_number} && $rr_number ne '0' && $rr_number ne $incident->{rr_number}) {
    $self->_log(
      info => {
        incident => $incident->{number},
        old_rr   => $rr_number,
        new_rr   => $incident->{rr_number},
        type     => 'incident_rr_change',
        message  => 'Cleaning up old jobs after rr_number change'
      }
    );

    # Individual jobs
    $db->query('DELETE FROM incident_openqa_settings WHERE incident = ?', $id);

    # Aggregate jobs
    $db->query('DELETE FROM incident_in_update WHERE incident = ?', $id);
  }

  # Add new channels
  my $old_channels
    = $db->query('SELECT name FROM channels c JOIN incident_channels ic ON ic.channel = c.id WHERE ic.incident = ?',
    $id)->arrays->map(sub { $_->[0] })->to_array;
  for my $channel (@{$incident->{channels}}) {
    $db->query('INSERT INTO channels (name) VALUES (?) ON CONFLICT DO NOTHING', $channel);
    my $cid = $db->query('SELECT id FROM channels WHERE name = ? LIMIT 1', $channel)->hash->{id};
    $db->query('INSERT INTO incident_channels (incident, channel) VALUES (?, ?) ON CONFLICT DO NOTHING', $id, $cid);

    @$old_channels = grep { $_ ne $channel } @$old_channels;
  }

  # Remove old channels that are no longer relevant
  for my $channel (@$old_channels) {
    my $cid = $db->query('SELECT id FROM channels WHERE name = ? LIMIT 1', $channel)->hash->{id};
    $db->query('DELETE FROM incident_channels WHERE incident = ? AND channel = ?', $id, $cid);
  }
}

sub _map ($self, $incident) {
  return undef unless $incident;
  @{$incident}{qw(isActive inReview inReviewQAM)}
    = (delete $incident->{active}, delete $incident->{review}, delete $incident->{review_qam});
  return $incident;
}

sub _log ($self, $level, $data) {
  $self->log->$level(Mojo::JSON::encode_json($data));
}

1;
