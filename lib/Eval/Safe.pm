package Eval::Safe;

use 5.022;
use strict;
use warnings;

use Carp;
use Eval::Safe::Eval;
use Eval::Safe::Safe;
use List::Util qw(none);

our $VERSION = '0.01';

# options:
#  - safe (int) default 0
#  - strict (bool) default 1
#  - warnings (bool) default 1

sub new {
  my ($class, %options) = @_;
  croak "Eval::Safe->new called with invalid class name: $class" unless $class eq 'Eval::Safe';
  my @known_options = qw(safe strict warnings debug);
  my @unknown_options = grep {my $k = $_; none { $k eq $_ } @known_options } keys %options; 
  if (@unknown_options) {
    croak "Unknown options: ".join(' ', @unknown_options);
  }
  $options{strict} = _make_pragma('strict', $options{strict});
  $options{warnings} = _make_pragma('warnings', $options{warnings});
  if ($options{safe} // 0 > 0) {
    return Eval::Safe::Safe->new(%options);
  } else {
    return Eval::Safe::Eval->new(%options);
  }
}

sub wrap {
  my ($this, $code) = @_;
  return $this->eval("sub { ${code} }");
}

sub share {
  my ($this, @vars) = @_;
  my $calling_package = caller;
  $this->share_from($calling_package, @vars);
}

sub share_from {
  my ($this, $package, @vars) = @_;
  $package = 'main' if $package eq '' || $package eq '::';
  croak "$package does not look like a package name" unless $package =~ m/^\w+(::\w+)*$/;
  croak "Package $package does not exist" unless eval "%${package}::";
  for my $v (@vars) {
    croak "Variable has no leading sigil: $v" unless $v =~ m'^([&*$%@])(\w+)$';
    my ($sigil, $symbol) = ($1, $2);
    # There are only 5 different sigils, so we could skip the eval here and
    # instead branch on the $sigil and use a syntax like the one on the left of
    # the equal (e.g. \&{$package."::$symbol"}). See:
    # https://metacpan.org/source/MICB/Safe-b2/Safe.pm
    no strict 'refs';
    *{($this->package())."::${symbol}"} = eval "\\${sigil}${package}::${symbol}";
  }
}

sub _make_pragma() {
  my ($pragma, $arg) = @_;
  my $ref = ref $arg;
  if ($ref eq '') {
    if ($arg) {
      return "use ${pragma};";
    } else {
      return "no ${pragma};";
    }
  } elsif ($ref eq 'SCALAR') {
    return "use ${pragma} '$arg';";
  } elsif ($ref eq 'ARRAY') {
    return ('use ${pragma} qw('.join(' ', @$arg).');');
  } else {
    croak "Invalid argument for '${pragma}' option, expected a scalar or array reference";
  }
}

1;

__DATA__

=pod

=head1 NAME

Eval::Safe - Simplified safe evaluation of Perl code

=head1 SYNOPSIS

B<Eval::Safe> is a Perl module to allow executing Perl code like with the
B<eval> function, but in isolation from the main program. This is similar to the
L<Safe> module, but faster, as we don't try to be safe.

  my $eval = Eval::Safe->new();
  $eval->eval($some_code);
  $eval->share('$foo');  # 'our $foo' can now be used in code provided to eval.

=head1 DESCRIPTION

The L<Safe> module does 3 things when running user-provided code: run the code
in a specific package so that variables in the calling code are not modified by
mistake; actually hide all the existing packages so that the executed code
cannot modify them; and limit the set of operations that can be executed by the
code to further try to make it safe (prevents it from modifying the system,
etc.).

The B<Eval::Safe> module here only does the first of these things (changing the 
namespace in which the code is executed) to make it conveniant to run
user-provided code, as long as you can trust that code. The benefit is that this
is around three times faster than using L<Safe> (especially for small pieces of
code).

=head2 eval

=head2 wrap

=head2 share

must have leading sigil (soo 'foo' is forbidden, not like in Safe::share, use
'&foo').
TODO: test that in the Safe code, or use the same approach as in Eval.

=head2 share_from

=head2 package

TODO: do (see do_load in ptp), varglob.

TODO: escape_string (Dumper(str) or quotemeta(str), diff?) this is independant
of the actual safe.

TODO: interpolate string.

TODO use module, probably need to be manually loaded like in ptp.


=head1 CAVEATS

Safe is slower than not safe

Exception may be ignored in safe mode.

Some operation won't work (use? load?).

=head1 AUTHOR

This program has been written by L<Mathias Kende|mailto:mathias@cpan.org>.

=head1 LICENCE

Copyright 2019 Mathias Kende

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=head1 SEE ALSO

L<Safe>, L<eval>

=cut