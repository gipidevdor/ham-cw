package Ham::CW::Error;
use 5.020;
use strict;
use warnings;
use overload q{""} => 'as_string', fallback => 1;
use Carp                     qw(croak);
use Storable                 qw(dclone);
use Ham::CW::_Internal::Data qw(plain_data);
our $VERSION = '0.001';

sub _argument_error {
    my ($message) = @_;
    croak bless {code => 'CW_E_ARGUMENT', message => $message, context => {}}, __PACKAGE__;
}

sub new {
    my ($class, @pairs) = @_;
    if (@pairs % 2) {
        _argument_error('Options must be name/value pairs');
    }
    my %args;
    my %allowed = map { $_ => 1 } qw(code message context);
    while (@pairs) {
        my ($name, $value) = splice @pairs, 0, 2;
        _argument_error('Unknown, duplicate or invalid error option')
            if !defined($name) || ref($name) || !$allowed{$name} || exists $args{$name};
        $args{$name} = $value;
    }
    for my $name (qw(code message)) {
        _argument_error("$name must be a defined scalar")
            if exists($args{$name}) && (!defined($args{$name}) || ref($args{$name}));
    }
    _argument_error('context must be a hash of plain, acyclic data, at most 64 levels deep')
        if exists($args{context})
        && (ref($args{context}) ne 'HASH' || !plain_data($args{context}));
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
Code and message must be defined scalars. Context must be an unblessed hash
containing acyclic arrays/hashes with scalar leaves, at most 64 levels deep.
Unknown/duplicate options and invalid payloads raise C<CW_E_ARGUMENT>.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
