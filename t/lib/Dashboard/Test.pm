# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Test;
use Mojo::Base -base, -signatures;

use Mojo::JSON qw(true false);
use Mojo::Pg;
use Mojo::URL;
use Mojo::Util qw(scope_guard);

has options => undef;

sub new ($class, %options) {

  # Database
  my $self = $class->SUPER::new(options => \%options);
  $self->{pg}       = Mojo::Pg->new($options{online});
  $self->{db_guard} = $self->_prepare_schema($options{schema});

  return $self;
}

sub default_config ($self) {
  return {
    secrets                 => ['just_a_test'],
    tokens                  => ['test_token'],
    pg                      => $self->postgres_url,
    openqa                  => {url => 'https://openqa.suse.de'},
    obs                     => {url => 'https://build.suse.de'},
    smelt                   => {url => 'https://smelt.suse.de'},
    days_to_keep_aggregates => 90
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
        embargoed   => true,
        isActive    => true,
        priority    => undef,
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
        embargoed   => true,
        isActive    => true,
        priority    => undef,
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
        embargoed   => true,
        isActive    => true,
        priority    => undef,
      },
      {
        number   => 29722,
        project  => 'SUSE:Maintenance:29722 ',
        packages => ['multipath-tools'],
        channels => [
          'SUSE:Updates:openSUSE-SLE:15.4',                       'SUSE:Updates:SLE-Module-Basesystem:15-SP4:x86_64',
          'SUSE:Updates:SLE-Module-Basesystem:15-SP4:s390x',      'SUSE:Updates:SLE-Module-Basesystem:15-SP4:aarch64',
          'SUSE:Updates:SLE-Module-Basesystem:15-SP4:ppc64le',    'SUSE:SLE-15-SP4:Update',
          'SUSE:Updates:SLE-Product-SLES:15-SP4-TERADATA:x86_64', 'SUSE:Updates:SLE-Micro:5.3:x86_64',
          'SUSE:Updates:SLE-Micro:5.3:aarch64',                   'SUSE:Updates:SLE-Micro:5.3:s390x',
          'SUSE:Updates:openSUSE-Leap-Micro:5.3',                 'SUSE:Updates:SLE-Micro:5.4:x86_64',
          'SUSE:Updates:SLE-Micro:5.4:s390x',                     'SUSE:Updates:SLE-Micro:5.4:aarch64',
          'SUSE:Updates:openSUSE-Leap-Micro:5.4'
        ],
        rr_number   => 302772,
        inReview    => true,
        inReviewQAM => true,
        approved    => false,
        emu         => false,
        embargoed   => false,
        isActive    => true,
        priority    => 700
        , # highest priority; supposed to show first on "Blocked" page and be highlighted for manual review as priority is above threshold
      },
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
  my $settings_four_id = $settings->add_incident_settings(
    $incidents->id_for_number(16861),
    {
      incident      => 16861,
      version       => '12-SP7',
      flavor        => 'Server-DVD-HA-Incidents-Install',
      arch          => 'aarch64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '12-SP7', BUILD => ':17063:perl-Mojolicious'}
    }
  );
  my $settings_five_id = $settings->add_incident_settings(
    $incidents->id_for_number(16862),
    {
      incident      => 16862,
      version       => '13-SP7',
      flavor        => 'Server-DVD-HA-Incidents-Install',
      arch          => 'aarch64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '13-SP7', BUILD => ':17063:curl'}
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
  $jobs->add(
    {
      incident_settings => $settings_four_id,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP7 Kernel Incidents',
      status            => 'passed',
      job_id            => 4973199,
      group_id          => 285,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'aarch64',
      version           => '12-SP7',
      build             => ':17063:perl-Mojolicious'
    }
  );
  $jobs->add(
    {
      incident_settings => $settings_five_id,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP7 Kernel Incidents',
      status            => 'passed',
      job_id            => 4983199,
      group_id          => 285,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'aarch64',
      version           => '12-SP7',
      build             => ':17063:curl'
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

  # Add failing build that is acceptable for a certain incident
  my @incident_numbers             = (16860, 29722);
  my @incident_ids                 = map { $incidents->id_for_number($_) } @incident_numbers;
  my $settings_acceptable_for_id_1 = $settings->add_incident_settings(
    $incident_ids[0],
    {
      incident      => $incident_ids[0],
      version       => '12-SP6',
      flavor        => 'Server-DVD-Incidents',
      arch          => 'x86_64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '12-SP6', BUILD => '20250317-1'}
    }
  ) unless $self->options->{schema} eq 'js_ui_test';
  my $settings_acceptable_for_id_2 = $settings->add_update_settings(
    \@incident_ids,
    {
      incidents => \@incident_numbers,
      product   => 'SLES-12-SP6',
      arch      => 'x86_64',
      build     => '20250317-1',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d37',
      settings  =>
        {DISTRI => 'sle', VERSION => '12-SP6', BUILD => '20201108-1', REPOHASH => 'd5815a9f8aa482ec8288508da27a9d37'}
    }
  );
  my $acceptable_for_16860_job_1_id = $jobs->add(
    {
      incident_settings => $settings_acceptable_for_id_1,
      update_settings   => $settings_acceptable_for_id_2,
      name              => 'acceptable_for_16860_despite_failing@64bit',
      job_group         => 'Server-DVD-Incidents 12-SP6',
      status            => 'failed',
      job_id            => 4953600,
      group_id          => 55,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP6',
      build             => '20250317-1'
    }
  );
  my $acceptable_for_16860_job_2_id = $jobs->add(
    {
      incident_settings => $settings_acceptable_for_id_1,
      update_settings   => $settings_acceptable_for_id_2,
      name              => 'acceptable_for_16860_but_passing_anyway@64bit',
      job_group         => 'Server-DVD-Incidents 12-SP6',
      status            => 'passed',
      job_id            => 4953601,
      group_id          => 55,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP6',
      build             => '20250317-1'
    }
  );
  $jobs->add_remark($acceptable_for_16860_job_1_id, $incident_ids[0], 'acceptable_for');

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

  # Aggregate with failed and passed jobs
  my $settings_multi_one_id = $settings->add_update_settings(
    [$incidents->id_for_number(29722)],
    {
      incident => 29722,
      product  => 'SAP-15-SP4',
      build    => '20230712-1',
      arch     => 'x86_64',
      repohash => 'c4b3ffa55d4ea7cba6cde4fc3edd1d55',
      settings => {
        ARCH     => 'x86_64',
        BUILD    => '20230712-1',
        DISTRI   => 'sle',
        FLAVOR   => 'SAP-DVD-Updates',
        VERSION  => '15-SP4',
        REPOHASH => 'c4b3ffa55d4ea7cba6cde4fc3edd1d55'
      }
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_multi_one_id,
      name              => 'sle-15-SP4-SAP-DVD-Updates-x86_64-Build20230712-1-qam-create_hdd_sles4sap_gnome@64bit',
      job_group         => 'SAP/HA Maintenance Updates',
      status            => 'passed',
      job_id            => 11559697,
      group_id          => 405,
      distri            => 'sle',
      flavor            => 'SAP-DVD-Updates',
      arch              => 'x86_64',
      version           => '15-SP4',
      build             => '20230712-1'
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_multi_one_id,
      name              => 'sle-15-SP4-SAP-DVD-Updates-x86_64-Build20230712-1-qam-sles4sap_scc_gnome_netweaver@64bit',
      job_group         => 'SAP/HA Maintenance Updates',
      status            => 'passed',
      job_id            => 11559696,
      group_id          => 405,
      distri            => 'sle',
      flavor            => 'SAP-DVD-Updates',
      arch              => 'x86_64',
      version           => '15-SP4',
      build             => '20230712-1'
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_multi_one_id,
      name      => 'sle-15-SP4-SAP-DVD-Updates-x86_64-Build20230712-1-qam_sles4sap_wmp_hana_node01@64bit-sap-qam',
      job_group => 'SAP/HA Maintenance Updates',
      status    => 'failed',
      job_id    => 11559373,
      group_id  => 405,
      distri    => 'sle',
      flavor    => 'SAP-DVD-Updates',
      arch      => 'x86_64',
      version   => '15-SP4',
      build     => '20230712-1'
    }
  );
  my $settings_multi_two_id = $settings->add_update_settings(
    [$incidents->id_for_number(29722)],
    {
      incident => 29722,
      product  => 'HA15SP4',
      build    => '20230709-1',
      arch     => 'x86_64',
      repohash => '3a006173b17fa83685ae9d74b1881d8a',
      settings => {
        ARCH     => 'x86_64',
        BUILD    => '20230709-1',
        DISTRI   => 'sle',
        FLAVOR   => 'Server-DVD-HA-Updates',
        VERSION  => '15-SP4',
        REPOHASH => '3a006173b17fa83685ae9d74b1881d8a'
      }
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_multi_two_id,
      name              => 'sle-15-SP4-Server-DVD-HA-Updates-x86_64-Build20230709-1-ha_qnetd_server@64bit',
      job_group         => 'SAP/HA Maintenance Updates',
      status            => 'passed',
      job_id            => 11548759,
      group_id          => 405,
      distri            => 'sle',
      flavor            => 'Server-DVD-HA-Updates',
      arch              => 'x86_64',
      version           => '15-SP4',
      build             => '20230712-1'
    }
  );
  $jobs->add(
    {
      incident_settings => undef,
      update_settings   => $settings_multi_two_id,
      name              => 'sle-15-SP4-Server-DVD-HA-Updates-x86_64-Build20230709-1-ha_qdevice_node2@64bit',
      job_group         => 'SAP/HA Maintenance Updates',
      status            => 'passed',
      job_id            => 9179106,
      group_id          => 405,
      distri            => 'sle',
      flavor            => 'Server-DVD-HA-Updates',
      arch              => 'x86_64',
      version           => '15-SP4',
      build             => '20230712-1'
    }
  );
}

sub no_fixtures ($self, $app) {
  $app->pg->migrations->migrate;
}

sub postgres_url ($self) {
  return Mojo::URL->new($self->{options}{online})->query([search_path => [$self->{options}{schema}]])->to_unsafe_string;
}

sub _prepare_schema ($self, $name) {

  # Isolate tests
  my $pg = $self->{pg};
  $pg->db->query("DROP SCHEMA IF EXISTS $name CASCADE");
  $pg->db->query("CREATE SCHEMA $name");

  # Clean up once we are done
  return scope_guard sub { $pg->db->query("DROP SCHEMA $name CASCADE") };
}

1;
