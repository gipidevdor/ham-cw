package Ham::CW::Result;
use 5.020;
use strict;
use warnings;
use Storable                     qw(dclone);
use Ham::CW::_Internal::Validate qw(fail number integer options named_arguments);
use Ham::CW::_Internal::Data     qw(plain_data);
use Ham::CW::Events              qw(validate_events);
use Ham::CW::_Internal::Result;
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(text morse events frequency wpm warnings complete diagnostics));
    for my $name (qw(text morse)) {
        fail('CW_E_ARGUMENT', "$name must be a defined scalar")
            if exists($args{$name}) && (!defined($args{$name}) || ref($args{$name}));
    }
    for my $name (qw(frequency wpm)) {
        number($name, $args{$name}, 0, 2**52) if defined $args{$name};
    }
    integer('complete', $args{complete}, 0, 1) if exists $args{complete};
    for my $name (qw(events warnings diagnostics)) {
        next unless exists $args{$name};
        my $kind = $name eq 'warnings' ? 'ARRAY' : 'HASH';
        fail('CW_E_ARGUMENT', "$name must contain plain, acyclic data, at most 64 levels deep")
            unless ref($args{$name}) eq $kind && plain_data($args{$name});
    }
    validate_events($args{events}) if exists $args{events};
    for my $warning (@{$args{warnings} // []}) {
        fail('CW_E_ARGUMENT', 'Each warning must contain scalar code and message fields')
            if ref($warning) ne 'HASH'
            || !defined($warning->{code})
            || ref($warning->{code})
            || !defined($warning->{message})
            || ref($warning->{message});
    }
    return Ham::CW::_Internal::Result->from_owned($class, %{dclone(\%args)});
}

sub has_text     { my ($self) = @_; return length($self->{text}) ? 1 : 0 }
sub has_warnings { my ($self) = @_; return @{$self->{warnings}}  ? 1 : 0 }
sub text         { my ($self) = @_; return $self->{text} }
sub morse        { my ($self) = @_; return $self->{morse} }
sub frequency    { my ($self) = @_; return $self->{frequency} }
sub wpm          { my ($self) = @_; return $self->{wpm} }
sub complete     { my ($self) = @_; return $self->{complete} }
sub events       { my ($self) = @_; return dclone($self->{events}) }
sub warnings     { my ($self) = @_; return dclone($self->{warnings}) }
sub diagnostics  { my ($self) = @_; return dclone($self->{diagnostics}) }
sub as_hash      { my ($self) = @_; return dclone({%{$self}}) }
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Result - immutable decoding snapshot

=head1 METHODS

=head2 new

C<new> accepts C<text>, C<morse>, C<events>, C<frequency> (Hz), C<wpm>,
C<warnings> (array of code/message hashes), C<complete> (boolean), and
C<diagnostics> (hash). Each field has an accessor of the same name.
Text and Morse must be defined scalars; frequency and WPM are nonnegative
finite numbers or undefined. Events must satisfy L<Ham::CW::Events>.
Warnings require scalar code and message fields. Reference-valued payloads
must be unblessed, acyclic arrays/hashes with scalar leaves, at most 64 levels
deep. Invalid field types raise C<CW_E_ARGUMENT> before copying.
C<has_text> returns true when text is nonempty. C<has_warnings> returns true
when at least one warning is present. Neither is a confidence or success
score. C<as_hash> returns all fields. Inputs and reference-valued outputs are deep
copies, and the top-level object hash is locked. Treat object internals as
private. Completion means finalization, not guaranteed signal confidence.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
