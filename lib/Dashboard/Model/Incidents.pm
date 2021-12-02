# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package Dashboard::Model::Incidents;
use Mojo::Base -base, -signatures;

has 'pg';

sub blocked ($self) {
  my $incidents = $self->pg->db->query(
    'SELECT * FROM incidents
     WHERE active = TRUE AND approved = FALSE AND review_qam = TRUE AND rr_number IS NOT NULL
     ORDER BY number'
  )->hashes->to_array;
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
    'SELECT build FROM incident_openqa_settings ios JOIN openqa_jobs
     oj ON oj.incident_settings=ios.id
    WHERE incident=? limit 1', $inc->{id}
  )->hash;
  return $settings->{build};
}

sub find ($self, $options = {}) {
  my $incidents = $self->pg->db->query(
    'SELECT number, project, packages, rr_number, review, review_qam, approved, emu, ARRAY_AGG(c.name) as channels
     FROM incidents i INNER JOIN incident_channels ic ON ic.incident = i.id INNER JOIN channels c ON ic.channel = c.id
     WHERE number = COALESCE(?, number) AND active = TRUE
     GROUP BY number, project, packages, rr_number, review, review_qam, approved, emu, active ORDER BY number',
    $options->{number}
  )->hashes->to_array;
  @{$_}{qw(isActive inReview inReviewQAM)} = (1, delete $_->{review}, delete $_->{review_qam}) for @$incidents;

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
    'SELECT oj.status,count(oj.id) FROM incident_openqa_settings ios JOIN openqa_jobs
            oj ON oj.incident_settings=ios.id  WHERE incident=? group by oj.status', $inc->{id}
  )->hashes;
  my %ret;
  for my $row ($res->each) {
    $ret{$row->{status}} = $row->{count};
  }
  return \%ret;
}

sub incident_for_number ($self, $number) {
  return $self->pg->db->query('select * from incidents where number = ? limit 1', $number)->hash;
}

sub id_for_number ($self, $number) {
  return undef
    unless my $array = $self->pg->db->query('select id from incidents where number = ? limit 1', $number)->array;
  return $array->[0];
}

sub name ($self, $inc) {
  return "$inc->{number}:unknown"
    unless my $hash
    = $self->pg->db->query('SELECT packages[1] as package FROM incidents WHERE number = ?', $inc->{number})->hash;
  return "$inc->{number}:$hash->{package}";
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

sub sync ($self, $incidents) {
  my $db = $self->pg->db;
  my $tx = $db->begin;

  $db->query('UPDATE incidents SET active = FALSE');
  for my $incident (@$incidents) { _update($db, $incident) }

  $tx->commit;
}

sub update ($self, $incident) {
  my $db = $self->pg->db;
  my $tx = $db->begin;

  _update($db, $incident);

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
  my $results = $db->query(
    'SELECT job_group, group_id, status, COUNT(status)
     FROM incident_openqa_settings os JOIN openqa_jobs oj on oj.incident_settings = os.id
     WHERE os.incident = ?
     GROUP BY job_group, group_id, status', $inc->{id}
  )->hashes;
  my %ret;
  for my $result ($results->each) {
    my $id = $result->{group_id};
    $ret{$id} ||= {linkinfo => $result->{group_id}, name => _group_nick($result->{job_group})};
    $ret{$id}{$result->{status}} = $result->{count};
  }

  for my $id (keys %ret) {
    my $settings = $db->query(
      'SELECT settings
       FROM openqa_jobs oj JOIN incident_openqa_settings os ON oj.incident_settings = os.id
       WHERE oj.group_id = ? AND os.incident = ? ORDER BY oj.job_id DESC LIMIT 1', $id, $inc->{id}
    )->expand->hash->{settings};
    $ret{$id}{linkinfo} = {distri => 'sle', groupid => $id, build => $settings->{BUILD}};
  }

  return \%ret;
}

sub _update_openqa_jobs ($self, $inc) {
  my $db = $self->pg->db;
  my $ids
    = $db->query('SELECT settings FROM incident_in_update WHERE incident = ?', $inc->{id})->arrays->flatten->to_array;

  my $results = $db->query(
    'SELECT job_group, group_id, us.build, oj.distri, oj.flavor, oj.arch, oj.version, status, COUNT(status)
     FROM update_openqa_settings us JOIN openqa_jobs oj on oj.update_settings = us.id
     WHERE us.id = ANY (?)
     GROUP BY job_group, group_id, us.build, oj.distri, oj.flavor, oj.arch, oj.version, status', $ids
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
    $ret{$id}{builds}{$result->{build}}{$result->{status}} = $result->{count};
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

sub _update ($db, $incident) {
  $db->query('INSERT INTO incidents (number, project) VALUES (?, ?) ON CONFLICT DO NOTHING',
    $incident->{number}, $incident->{project});
  my $id = $db->query('SELECT id FROM incidents WHERE number = ? LIMIT 1', $incident->{number})->hash->{id};

  $db->query(
    'UPDATE incidents SET packages = ?, rr_number = ?, review = ?, review_qam = ?, approved = ?, emu = ?, active = ?
       WHERE id = ?', $incident->{packages}, $incident->{rr_number}, $incident->{inReview}, $incident->{inReviewQAM},
    $incident->{approved}, $incident->{emu}, $incident->{isActive}, $id
  );

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

1;
