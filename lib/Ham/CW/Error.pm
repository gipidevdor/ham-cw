package Ham::CW::Error;
use 5.020;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use Carp     qw(croak);
use Storable qw(dclone);
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    if (@pairs % 2) {
        croak $class->new(code => 'CW_E_ARGUMENT', message => 'Options must be name/value pairs');
    }
    my %args = @pairs;
    return bless {
        code    => $args{code}    // 'CW_E_INTERNAL',
        message => $args{message} // 'Unspecified error',
        context => dclone($args{context} // {})
    }, $class;
}
sub throw     { my ($class, @args) = @_; croak $class->new(@args) }
sub code      { my ($self) = @_; return $self->{code} }
sub message   { my ($self) = @_; return $self->{message} }
sub context   { my ($self) = @_; return dclone($self->{context}) }
sub as_string { my ($self) = @_; return $self->{code} . ': ' . $self->{message} }
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Error - structured CW exceptions

=head1 SYNOPSIS

    eval { $cw->encode("\x{2603}") };
    if (ref $@ && $@->isa('Ham::CW::Error')) {
        warn $@->code . ': ' . $@->message;
    }

=head1 METHODS

=head2 new

C<new(code =E<gt> ..., message =E<gt> ..., context =E<gt> {})> constructs an
exception. C<throw> constructs and dies with it. C<code>, C<message>, and
C<context> expose its fields; context is copied. C<as_string> also supplies
string overloading. Public codes are listed in L<Ham::CW/ERRORS>.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
