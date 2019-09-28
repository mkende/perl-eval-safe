#!/usr/bin/perl

use strict;
use warnings;

use Eval::Safe;
use Test::More;

plan tests => 8;

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

my $package;
{
  my $eval = Eval::Safe->new(safe => 0);
  $package = $eval->package();
  $eval->eval("\$${package}::Sub::foo = 1");
  no strict 'refs';
  ok(%{"${package}::Sub::"}, 'sub package is created');
}{
  no strict 'refs';
  ok(!%{"${package}::Sub::"}, 'sub package is deleted');
}{
  my $eval = Eval::Safe->new(safe => 1);
  $package = $eval->package();
  $eval->eval('$Sub::foo = 1');
  no strict 'refs';
  ok(%{"${package}::Sub::"}, 'sub package is created safe');
}{
  no strict 'refs';
  ok(!%{"${package}::Sub::"}, 'sub package is deleted safe');
}
