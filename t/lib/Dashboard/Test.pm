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

package Dashboard::Test;
use Mojo::Base -base, -signatures;

use Mojo::JSON qw(true false);
use Mojo::Pg;
use Mojo::URL;
use Mojo::Util qw(scope_guard);

sub new ($class, %options) {

  # Database
  my $self = $class->SUPER::new(options => \%options);
  $self->{pg}       = Mojo::Pg->new($options{online});
  $self->{db_guard} = $self->_prepare_schema($options{schema});

  return $self;
}

sub default_config ($self) {
  return {
    secrets => ['just_a_test'],
    tokens  => ['test_token'],
    pg      => $self->postgres_url,
    openqa  => {url => 'https://openqa.suse.de'},
    obs     => {url => 'https://build.suse.de'},
    smelt   => {url => 'https://smelt.suse.de'}
  };
}

sub minimal_fixtures ($self, $app) {
  $self->no_fixtures($app);

  my $incidents = $app->incidents;
  $incidents->sync(
    [
      {
        number      => 16860,
        project     => 'SUSE:Maintenance:16860',
        packages    => ['perl-Mojolicious'],
        channels    => ['Test'],
        rr_number   => 230066,
        inReview    => true,
        inReviewQAM => true,
        approved    => false,
        emu         => true,
        isActive    => true
      },
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Minion', 'perl-Mojo-Pg'],
        channels    => ['Test'],
        rr_number   => undef,
        inReview    => true,
        inReviewQAM => true,
        approved    => false,
        emu         => true,
        isActive    => true
      },
      {
        number      => 16862,
        project     => 'SUSE:Maintenance:16862',
        packages    => ['curl'],
        channels    => ['Test'],
        rr_number   => undef,
        inReview    => true,
        inReviewQAM => true,
        approved    => true,
        emu         => true,
        isActive    => true
      }
    ]
  );

  my $settings        = $app->settings;
  my $incident_id     = $incidents->id_for_number(16860);
  my $settings_one_id = $settings->add_incident_settings(
    $incident_id,
    {
      incident      => 16860,
      version       => '12-SP5',
      flavor        => 'Server-DVD-HA-Incidents-Install',
      arch          => 'x86_64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '12-SP5', BUILD => ':17063:perl-Mojolicious'}
    }
  );
  my $settings_two_id = $settings->add_incident_settings(
    $incident_id,
    {
      incident      => 16860,
      version       => '12-SP4',
      flavor        => 'Server-DVD-HA-Incidents-Install',
      arch          => 'x86_64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '12-SP4', BUILD => ':17063:perl-Mojolicious'}
    }
  );
  my $settings_three_id = $settings->add_incident_settings(
    $incident_id,
    {
      incident      => 16860,
      version       => '12-SP5',
      flavor        => 'Server-DVD-HA-Incidents-Install',
      arch          => 'aarch64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '12-SP5', BUILD => ':17063:perl-Mojolicious'}
    }
  );

  my $jobs = $app->jobs;
  $jobs->add(
    {
      incident_settings => $settings_one_id,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'waiting',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:perl-Mojolicious'
    }
  );
  $jobs->add(
    {
      incident_settings => $settings_two_id,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP4 Incidents',
      status            => 'failed',
      job_id            => 4953194,
      group_id          => 284,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP4',
      build             => ':17063:perl-Mojolicious'
    }
  );
  $jobs->add(
    {
      incident_settings => $settings_three_id,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Kernel Incidents',
      status            => 'passed',
      job_id            => 4953195,
      group_id          => 283,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'aarch64',
      version           => '12-SP5',
      build             => ':17063:perl-Mojolicious'
    }
  );

  # Successful build
  my $settings_success_id = $settings->add_update_settings(
    [map { $incidents->id_for_number($_) } 16860, 16861],
    {
      incidents => [16860, 16861],
      product   => 'SLES-12-SP5',
      arch      => 'x86_64',
      build     => '20201107-1',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d36',
      settings  =>
        {DISTRI => 'sle', VERSION => '12-SP5', BUILD => '20201107-1', REPOHASH => 'd5815a9f8aa482ec8288508da27a9d36'}
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_success_id,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Updates',
      status            => 'passed',
      job_id            => 4953199,
      group_id          => 54,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => '20201107-1'
    }
  );

  # Failing build
  my $settings_failing_id = $settings->add_update_settings(
    [map { $incidents->id_for_number($_) } 16860, 16861],
    {
      incidents => [16860, 16861],
      product   => 'SLES-12-SP5',
      arch      => 'x86_64',
      build     => '20201107-2',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d37',
      settings  =>
        {DISTRI => 'sle', VERSION => '12-SP5', BUILD => '20201107-2', REPOHASH => 'd5815a9f8aa482ec8288508da27a9d37'}
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_failing_id,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Updates',
      status            => 'passed',
      job_id            => 4953205,
      group_id          => 54,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'aarch64',
      version           => '12-SP5',
      build             => '20201107-2'
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_failing_id,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Updates',
      status            => 'failed',
      job_id            => 4953200,
      group_id          => 54,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => '20201107-2'
    }
  );

  # Waiting build
  my $settings_waiting_id = $settings->add_update_settings(
    [map { $incidents->id_for_number($_) } 16860, 16861],
    {
      incidents => [16860, 16861],
      product   => 'SLES-12-SP5',
      arch      => 'x86_64',
      build     => '20201108-1',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d38',
      settings  =>
        {DISTRI => 'sle', VERSION => '12-SP5', BUILD => '20201108-1', REPOHASH => 'd5815a9f8aa482ec8288508da27a9d38'}
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_waiting_id,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Updates',
      status            => 'waiting',
      job_id            => 4953203,
      group_id          => 54,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => '20201108-1'
    }
  );
}

sub no_fixtures ($self, $app) {
  $app->pg->migrations->migrate;
}

sub postgres_url ($self) {
  return Mojo::URL->new($self->{options}{online})->query([search_path => [$self->{options}{schema}, 'public']])
    ->to_unsafe_string;
}

sub _prepare_schema ($self, $name) {

  # Isolate tests
  my $pg = $self->{pg};
  $pg->db->query("drop schema if exists $name cascade");
  $pg->db->query("create schema $name");

  # Clean up once we are done
  return scope_guard sub { $pg->db->query("drop schema $name cascade") };
}

1;
