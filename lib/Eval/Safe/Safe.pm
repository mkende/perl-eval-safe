# This is an implementation of Eval::Safe that uses the Safe module to execute
# the user provided code.

package Eval::Safe::Safe;

use 5.022;
use strict;
use warnings;

use parent 'Eval::Safe';

use Carp;
use Eval::Safe::ForkedSafe;

sub new {
  my ($class, %options) = @_;
  my $self = bless \%options, $class;
  my $safe = Eval::Safe::ForkedSafe->new($options{package});
  # This option is always set if we're building an Eval::Safe::Safe.
  if ($self->{safe} > 1) {
    $safe->permit_only(qw(:base_core :base_mem :base_loop :base_math :base_orig
                          :load));
    $safe->deny(qw(tie untie bless));
  } else {
    $safe->deny_only(qw(:subprocess :ownprocess :others :dangerous));
  }
  $self->{safe} = $safe;
  return $self;
}

sub eval {
  my ($this, $code) = @_;
  my $eval_str = sprintf "%s; %s; %s", $this->{strict}, $this->{warnings}, $code;
  print {$this->{debug}} "Evaling (safe): '${eval_str}'\n" if $this->{debug};
  return $this->{safe}->reval($eval_str);
}

sub package {
  my ($this) = @_;
  return $this->{safe}->root();
}

1;
