package Ham::CW::Encoder;
use 5.020;
use strict;
use warnings;
use Ham::CW::_Internal::Symbols  qw(alphabet prosigns);
use Ham::CW::_Internal::Validate qw(fail number options named_arguments);
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(wpm effective_wpm unknown));
    my $wpm       = number('wpm',           $args{wpm}           // 20,   1, 200);
    my $effective = number('effective_wpm', $args{effective_wpm} // $wpm, 1, $wpm);
    my $unknown   = $args{unknown} // 'error';
    fail('CW_E_ARGUMENT', 'unknown must be error or skip') unless $unknown =~ /\A(?:error|skip)\z/x;
    return bless {wpm => $wpm, effective_wpm => $effective, unknown => $unknown}, $class;
}

sub encode {
    my ($self, $text) = @_;
    fail('CW_E_ARGUMENT', 'Text must be a defined scalar') if !defined($text) || ref($text);
    my $a = alphabet();
    my $p = prosigns();
    my @words;
    for my $word (split /\s+/x, $text) {
        next unless length $word;
        my @codes;
        while (length $word) {
            my ($token, $code);
            if ($word =~ s/\A<([A-Za-z]+)>//x) {
                $token = "<$1>";
                $code  = $p->{uc $1};
            }
            else {
                $token = substr($word, 0, 1, '');

                # Uppercase only the explicitly supported alphabet; no transliteration.
                my $upper = $token =~ /[a-z\x{e9}]/x ? uc($token) : $token;
                $code = $a->{$upper};
            }
            if (!defined $code) {
                next if $self->{unknown} eq 'skip';
                fail('CW_E_SYMBOL', 'Unsupported text symbol');
            }
            push @codes, $code;
        }
        push @words, join(' ', @codes) if @codes;
    }
    return join(' / ', @words);
}

sub events {
    my ($self, $text) = @_;
    my $morse = $self->encode($text);
    my $dot   = 1_200_000 / $self->{wpm};
    my $space = (60_000_000 / $self->{effective_wpm} - 31 * $dot) / 19;
    my (@segments, $time, $boundary);
    $time = $boundary = 0;
    my $append = sub {
        my ($state, $duration) = @_;
        $time += $duration;
        my $end = int($time + 0.5);
        push @segments, {state => $state, duration => $end - $boundary};
        $boundary = $end;
    };
    my @words = split m{\x20/\x20}x, $morse;
    for my $wi (0 .. $#words) {
        $append->('off', 7 * $space) if $wi;
        my @letters = split /\x20/x, $words[$wi];
        for my $li (0 .. $#letters) {
            $append->('off', 3 * $space) if $li;
            my @marks = split //, $letters[$li];
            for my $mi (0 .. $#marks) {
                $append->('off', $dot) if $mi;
                $append->('on',  ($marks[$mi] eq '.' ? 1 : 3) * $dot);
            }
        }
    }
    return {unit => 'us', segments => \@segments};
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Encoder - international Morse text and timing

=head1 SYNOPSIS

    my $encoder = Ham::CW::Encoder->new(wpm => 20, effective_wpm => 12);
    my $morse = $encoder->encode('CQ <AR>');
    my $events = $encoder->events('LIGHT');

=head1 METHODS

C<new> accepts C<wpm> (default 20, range 1..200), C<effective_wpm>
(default WPM, range 1..WPM), and C<unknown> (C<error> or C<skip>).
Unknown options are errors. C<encode(text)> returns dot/dash groups separated
by one space, with C< / > between words. Whitespace is collapsed and ASCII
letters are uppercased. Accented E is supported explicitly; other Unicode
characters are rejected, without transliteration. Empty text is allowed.

Operational tokens use angle brackets: C<< <AR> >>, C<< <AS> >>, C<< <CT> >>, C<< <SK> >>,
C<< <HH> >>, C<< <SN> >>, and C<< <SOS> >>.
Ordinary C<AR> remains two letters. Shared punctuation/prosign waveforms are
inherently ambiguous on reception; see L<Ham::CW::Decoder>.

C<events(text)> returns canonical TimedEvents with integer microseconds.
Dot length is 1,200,000/WPM. Farnsworth uses a 50-unit reference word: 31 units
of marks/intra-character gaps and 19 units of extended spacing per word.
Cumulative boundaries round to nearest integer, half upward. No terminal
word gap is appended. Text encoding is atomic; split text only at token
boundaries, adding the intended separating whitespace yourself.

=head1 STANDARD

ITU-R M.1677-1 (2009), Annex 1. C<É> is included; nonstandard exclamation,
semicolon, underscore and dollar signs are deliberately excluded.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
