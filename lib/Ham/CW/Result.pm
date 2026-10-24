package Ham::CW::Result;
use 5.020;
use strict;
use warnings;
use Storable                     qw(dclone);
use Hash::Util                   qw(lock_hash);
use Ham::CW::_Internal::Validate qw(options named_arguments);
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(text morse events frequency wpm warnings complete diagnostics));
    my $self = bless dclone(
        {
            text        => '',
            morse       => '',
            events      => [],
            frequency   => undef,
            wpm         => undef,
            warnings    => [],
            complete    => 0,
            diagnostics => {},
            %args
        }
    ), $class;
    lock_hash(%{$self});
    return $self;
}
sub text        { my ($self) = @_; return $self->{text} }
sub morse       { my ($self) = @_; return $self->{morse} }
sub frequency   { my ($self) = @_; return $self->{frequency} }
sub wpm         { my ($self) = @_; return $self->{wpm} }
sub complete    { my ($self) = @_; return $self->{complete} }
sub events      { my ($self) = @_; return dclone($self->{events}) }
sub warnings    { my ($self) = @_; return dclone($self->{warnings}) }
sub diagnostics { my ($self) = @_; return dclone($self->{diagnostics}) }
sub as_hash     { my ($self) = @_; return dclone({%{$self}}) }
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Result - immutable decoding snapshot

=head1 METHODS

C<new> accepts C<text>, C<morse>, C<events>, C<frequency> (Hz), C<wpm>,
C<warnings> (array of code/message hashes), C<complete> (boolean), and
C<diagnostics> (hash). Each field has an accessor of the same name.
C<as_hash> returns all fields. Inputs and reference-valued outputs are deep
copies, and the top-level object hash is locked. Treat object internals as
private. Completion means finalization, not guaranteed signal confidence.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
