package Eval::Safe::Eval;

use 5.022;
use strict;
use warnings;

use parent 'Eval::Safe';

use Carp;

# Count the number of Eval::Safe::Eval object created to assign each of them a
# specific package name.
my $env_count = 0;

sub new {
  my ($class, %options) = @_;
  my $self = bless \%options, $class;
  $self->{package} = 'Eval::Safe::Eval::Env'.($env_count++);
  return $self;
}

sub DESTROY {
  local($., $@, $!, $^E, $?);
  my ($this) = @_;
  CORE::eval('undef %'.($this->{package}).'::');
}

sub eval {
  my ($this, $code) = @_;
  my $eval_str = sprintf "package %s; %s; %s; %s", $this->{package},
                        $this->{strict}, $this->{warnings}, $code;
  print {$this->{debug}} "Evaling (eval): '${eval_str}'\n" if $this->{debug};
  return CORE::eval($eval_str);
}

sub package {
  my ($this) = @_;
  return $this->{package};
}

1;
