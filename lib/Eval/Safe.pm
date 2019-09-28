package Eval::Safe;

use 5.022;
use strict;
use warnings;

use Carp;
use Eval::Safe::Eval;
use Eval::Safe::Safe;
use List::Util qw(none);
use Scalar::Util qw(reftype refaddr);

our $VERSION = '0.01';

sub new {
  my ($class, %options) = @_;
  croak "Eval::Safe->new called with invalid class name: $class" unless $class eq 'Eval::Safe';
  my @known_options = qw(safe strict warnings debug package);
  my @unknown_options = grep {my $k = $_; none { $k eq $_ } @known_options } keys %options; 
  if (@unknown_options) {
    croak "Unknown options: ".join(' ', @unknown_options);
  }
  $options{strict} = _make_pragma('strict', $options{strict});
  $options{warnings} = _make_pragma('warnings', $options{warnings});
  if ($options{package}) {
    $options{package} = Eval::Safe::_validate_package_name($options{package});
    croak "Package $options{package} already not exist" if eval "%$options{package}::";
  }
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
  $package = _validate_package_name($package);
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

sub var_ref {
  my ($this, $var) = @_;
  croak "Variable has no leading sigil: $var" unless $var =~ m'^([&*$%@])(\w+)$';
  # There are only 5 different sigils, so we could skip the eval here and
  # instead branch on the $sigil. See:
  # https://metacpan.org/source/MICB/Safe-b2/Safe.pm
  no strict 'refs';
  return eval sprintf '\%s%s::%s', $1, $this->package(), $2;
}

sub interpolate {
  my ($this, $str) = @_;
  # It's not clear if Text::Balanced could help here.
  my $r = $this->eval("<<\"EVAL_SAFE_EOF_WORD\"\n${str}\nEVAL_SAFE_EOF_WORD\n");
  $r =~ s/\n$//;
  return $r;
}

# _make_pragma('pragma', $arg)
# Returns a string saying "no pragma" if $arg is false, "use pragma" if arg is
# a `true` scalar, "use pragma $$arg" if arg is a scalar reference, and
# "use pragma @$arg" if arg is an array reference.
sub _make_pragma() {
  my ($pragma, $arg) = @_;
  my $reftype = reftype $arg;
  if (not defined $reftype) {
    if ($arg) {
      return "use ${pragma};";
    } else {
      return "no ${pragma};";
    }
  } elsif ($reftype eq 'SCALAR') {
    return "use ${pragma} '$arg';";
  } elsif ($reftype eq 'ARRAY') {
    return ('use ${pragma} qw('.join(' ', @$arg).');');
  } elsif ($reftype eq 'HASH') {
    return ('use ${pragma} qw('.join(' ', %$arg).');');
  } else {
    croak "Invalid argument for '${pragma}' option, expected a scalar or array reference";
  }
}

# $safe->_wrap_code_refs('sub', @objects)
# will call $safe->sub($ref) for all code references found within @objects and
# store the result in place in @objects. The passed objects are crawled
# recursively.
# Finally, the modified array is returned.
#
# This is similar to the wrap_code_refs_within method in Safe.
sub _wrap_code_refs {
  my ($this, $wrapper) = splice @_, 0, 2;
  # We need to use @_ below (without giving it a new name) to retain its
  # aliasing property to modify the arguments in-place.
  my %seen_refs = ();
  my $crawler = sub {
    for my $item (@_) {
      my $reftype = reftype $item;
      next unless $reftype;
      next if ++$seen_refs{refaddr $item} > 1;
      if ($reftype eq 'ARRAY') {
          __SUB__->(@$item);  # __SUB__ is the current sub.
      } elsif ($reftype eq 'HASH') {
          __SUB__->(values %$item);
      } elsif ($reftype eq 'CODE') {
          $item = $this->$wrapper($item);
      }
      # We're ignoring the GLOBs for the time being.
    }
  };
  $crawler->(@_);
  if (defined wantarray) {
    return (wantarray) ? @_ : $_[0];
  }
  return;
}

# _validate_package_name('package::name')
# Croaks (dies) if the given package name does not look like a package name.
# Otherwise returns a cleaned form of the package name (trailing '::' are
# removed, and '' or '::' is made into 'main').
sub _validate_package_name {
  my ($p) = @_;
  $p =~ s/::$//;
  $p = 'main' if $p eq '';
  croak "${p} does not look like a package name" unless $p =~ m/^\w+(::\w+)*$/;
  return $p;
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

=head2 Safe::eval->new(%options)

=over 4

=item B<safe> => I<int>

=item B<strict> => I<options>

=item B<warnings> => I<options>

=item B<debug> => I<int>

=item B<package> => I<string>

=back

=head2 DESTROY

When the object goes out of scope, its main package and all its sub-packages are
deleted automatically.

=head2 $eval->eval($code)

Executes the given string as Perl code in the environment of the current object.

The current package seen by the code will be a package specific to the
Safe::Eval object (that is initially empty). How that package is exposed depends
on the value of the B<safe> option passed to the constructor, if any. If the
option was not passed (or was passed a C<false> value), then the code will have
access to the content of all the existing packages and will see the real name
of its package. If the B<safe> option was passed a C<true> value, then the code
will believe that it runs in the root package and it will not have access to the
content of any other existing packages.

In all cases, if the code passed to C<eval> cannot be compiled or if it dies
during its execution, then the call to C<eval> will return C<undef> and C<$@>
will be set.

If the call returns a code reference or a data-structure that contains code
references, these references are all modified so that when executed they will
run as if through this C<eval> method. In particular, exceptions will be trapped
and C<$@> will be set instead. This property is recursive to all the
code-references possibly returned in turn by these functions.

=head2 $eval->wrap($code)

Returns a code-reference that, when executed, execute the content of the Perl
code passed in the string in the context of the Eval::Safe object. This call is
similar to C<$eval->eval("sub { STR }")>.

=head2 $eval->share('$var', '@foo', ...)

Shares the listed variables from the current package with the Perl environment
of the Eval::Safe object. The list must be a list of strings containing the
names of the variables to share, including their leading sigils (one of B<$>,
B<@>, B<%>, B<&>, or B<*>). When sharing a glob (C<*foo>) then all the C<foo>
variables are shared.

=head2 $eval->share_from('Package', '$var', ...)

Shares the listed variables from a specific package. The variables are shared
into the main package of the Perl environment of the Eval::Safe object as when
using the C<share> method.

=head2 package

=head2 interpolate

=head2 var_ref

TODO: do (see do_load in ptp), varglob.

TODO use module, probably need to be manually loaded like in ptp.


=head1 CAVEATS

Safe is slower than not safe

To bypass a bug with the Safe that hides all exceptions that could occur in code
wrapped by it, this module is using a forked version of the Safe module.

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