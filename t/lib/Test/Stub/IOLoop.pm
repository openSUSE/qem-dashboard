# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Test::Stub::IOLoop;
use Mojo::Base -strict, -signatures;
use Test::MockModule;

sub stub_timer ($cls, $delays_ref) {
  my $ioloop = Test::MockModule->new('Mojo::IOLoop');
  $ioloop->redefine(
    timer => sub ($loop, $delay, $cb) {
      push @$delays_ref, $delay if defined $delay;
    }
  );
  return $ioloop;
}

1;

=encoding utf8

=head1 NAME

Test::Stub::IOLoop - stub C<Mojo::IOLoop> timers for testing

=head1 SYNOPSIS

  use Test::Stub::IOLoop;

  Test::Stub::IOLoop->stub_timer(\@delays);

=head1 DESCRIPTION

Replaces C<Mojo::IOLoop::timer> with a stub that records requested
delays into an array reference instead of scheduling real
timers. Useful for avoiding to wait for actual time to pass.

=cut
