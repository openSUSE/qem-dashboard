# Copyright (C) SUSE LLC
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

package Dashboard::Model::OpenQA;
use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::URL;

has [qw(pg log ua)];

sub details ($self, $id) {
  $self->log->info("Fetching job $id");

  my $url = $self->_openqa_url->path("/api/v1/jobs/$id");
  my $res = $self->ua->get($url => {Accept => 'application/json'})->result;
  if ($res->is_error) {
    $self->log->error($res->message);
    return undef;
  }
  return $res->json->{job};
}

sub fetch_old_chunk ($self, $id, $job_model) {
  my $delta = $self->_delta;
  $self->log->info("Fetching $delta jobs starting $id");

  my $url = $self->_openqa_url->path('/api/v1/jobs')->query(ids => [($id .. $id + $delta)]);
  $self->ua->get_p($url => {Accept => 'application/json'})->then(
    sub ($tx) {

      my %seen_jobs;
      if ($tx->error) {
        $self->log->error(Mojo::Util::dumper($tx));
        return;
      }
      my $json = $tx->result->json;
      for my $job (@{$json->{jobs}}) {
        $job_model->update_or_insert_job($job);
        $seen_jobs{$job->{id}} = 1;
      }

      # jobs not returned by openQA are deleted and aren't worth waiting for
      for my $i ($id .. $id + $delta) {
        if (!defined $seen_jobs{$i}) {
          $self->pg->db->query("update openqa_jobs set status='failed' where status='waiting' and job_id=?", $i);
        }
      }
      if (!@{$json->{jobs}}) {
        $self->log->info("All old jobs fetched");
        return;
      }
      $self->fetch_old_chunk($id + $delta + 1, $job_model);
    }
  );
}

# for easier mocking - we may want to make this configurable, but 50 jobs seem to be a good compromise
# and the value isn't free to choose, around 80 jobs will already create too long URLs
sub _delta ($self) {
  return 50;
}

sub _openqa_url ($self) {
  return Mojo::URL->new('https://openqa.suse.de');
}


1;
