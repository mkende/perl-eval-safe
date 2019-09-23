#!/usr/bin/perl

use strict;
use warnings;

use Eval::Safe;
use Test::More;

plan tests => 1;

# Test the behavior of 'die', 'warn', etc in the safe.

# Test that bad code will set $@ (at compile time, at execution time of wrapped
# code?)...

ok(1);
