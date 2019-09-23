#!/usr/bin/perl

use strict;
use warnings;

use Eval::Safe;
use Test::More;

plan tests => 2 * 2;

# TODO test that the package used is correctly cleaned when an object is deleted.

for my $safe (0..1) {
  my $s = $safe ? ' safe' : '';
  my $package;
  {
    my $eval = Eval::Safe->new(safe => $safe);
    $eval->eval('$foo = 1');
    no strict 'refs';
    $package = $eval->package();
    ok(%{"${package}::"}, 'package is created'.$s);
  }{
    no strict 'refs';
    ok(!%{"${package}::"}, 'package is deleted'.$s);
  }
}
