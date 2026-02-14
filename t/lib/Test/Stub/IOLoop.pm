# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Test::Stub::IOLoop;
use Mojo::Base -strict, -signatures;

sub stub_timer ($cls, $delays_ref) {
  no warnings 'redefine', 'once';

  *Mojo::IOLoop::timer = sub ($loop, $delay, $cb) {
    push @$delays_ref, $delay if defined $delay;
    return;
  };

  return;
}

1;
