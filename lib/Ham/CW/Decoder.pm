package Ham::CW::Decoder;
use 5.020;
use strict;
use warnings;
use Storable                     qw(dclone);
use Ham::CW::Events              qw(validate_events to_timed);
use Ham::CW::_Internal::Symbols  qw(reverse_alphabet prosigns);
use Ham::CW::_Internal::Validate qw(fail number integer options named_arguments);
use Ham::CW::Result;
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(wpm effective_wpm prefer_prosigns max_segments));
    number('wpm',           $args{wpm},           1, 200) if defined $args{wpm};
    number('effective_wpm', $args{effective_wpm}, 1, $args{wpm} // 200)
        if defined $args{effective_wpm};
    integer('max_segments', $args{max_segments} // 100000, 1, 1000000);
    my $reverse = reverse_alphabet();
    if ($args{prefer_prosigns}) {
        my $p = prosigns();
        $reverse->{$p->{$_}} = "<$_>" for sort keys %{$p};
    }
    my $self = bless {reverse => $reverse, %args, max_segments => $args{max_segments} // 100000},
        $class;
    return $self->reset;
}

sub reset {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($self) = @_;
    $self->{state}          = 'READY';
    $self->{segments}       = [];
    $self->{kind}           = undef;
    $self->{rate}           = undef;
    $self->{total_duration} = 0;
    $self->{snapshot}       = undef;
    $self->{final}          = undef;
    return $self;
}
sub state { my ($self) = @_; return $self->{state} }    ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub decode {
    my ($self, $morse) = @_;
    fail('CW_E_ARGUMENT', 'Morse must be a defined scalar') if !defined($morse) || ref($morse);
    $morse =~ s/\A\s+|\s+\z//gx;
    return '' unless length $morse;
    fail('CW_E_SYMBOL',
        'Invalid Morse syntax; use spaces between letters and / between words, e.g. ... --- ...')
        unless $morse =~ /\A[.\-]+(?:\s+[.\-]+)*(?:\s*\/\s*[.\-]+(?:\s+[.\-]+)*)*\z/x;
    my $reverse = $self->{reverse};
    my @words;
    for my $word (split /\s*\/\s*/x, $morse) {
        my $text = '';
        for my $code (split /\s+/x, $word) {
            fail('CW_E_SYMBOL', "Unknown Morse group '$code'; separate letters with spaces")
                unless exists $reverse->{$code};
            $text .= $reverse->{$code};
        }
        push @words, $text;
    }
    return join ' ', @words;
}

sub feed {
    my ($self, $events) = @_;
    fail('CW_E_STATE', 'Decoder is finalized; reset before feeding')
        if $self->{state} eq 'FINISHED';
    my $kind = validate_events($events);
    my $rate = $events->{sample_rate};
    fail('CW_E_ARGUMENT', 'Event units or sample rate changed')
        if defined($self->{kind})
        && ($self->{kind} ne $kind || ($kind eq 'samples' && $self->{rate} != $rate));
    my $joins =
           @{$self->{segments}}
        && @{$events->{segments}}
        && $self->{segments}[-1]{state} eq $events->{segments}[0]{state} ? 1 : 0;
    fail('CW_E_RESOURCE',
        'Decoder segment limit exceeded; increase max_segments or decode shorter sequences')
        if @{$self->{segments}} + @{$events->{segments}} - $joins > $self->{max_segments};
    my $added = 0;
    $added += $_->{$kind} for @{$events->{segments}};
    fail('CW_E_RESOURCE', 'Cumulative event duration exceeds exact integer range')
        if $self->{total_duration} + $added > 2**52;
    my $copy = dclone($events->{segments});

    if (@{$copy} && @{$self->{segments}} && $copy->[0]{state} eq $self->{segments}[-1]{state}) {
        my $sum = $copy->[0]{$kind} + $self->{segments}[-1]{$kind};
        $copy->[0]{$kind} = $sum;
        pop @{$self->{segments}};
    }
    push @{$self->{segments}}, @{$copy};
    $self->{total_duration} += $added;
    $self->{kind}     = $kind;
    $self->{rate}     = $rate;
    $self->{state}    = 'ACTIVE';
    $self->{snapshot} = undef;
    return $self;
}

sub _estimate_dot {
    my ($segments) = @_;
    my @on = sort { $a <=> $b } map { $_->{duration} }
        grep { $_->{state} eq 'on' } @{$segments};
    return (undef, []) unless @on;
    my ($best, $cost);
    for my $value (@on[0 .. ($#on < 31 ? $#on : 31)]) {
        for my $candidate ($value, $value / 3) {
            next if $candidate < 20000 || $candidate > 240000;
            my $loss = 0;
            for my $duration (@on) {
                my $ratio = $duration / $candidate;
                my $distance =
                    abs($ratio - 1) < abs($ratio - 3) ? abs($ratio - 1) : abs($ratio - 3);
                $loss += $distance * $distance;
            }
            if (!defined($cost) || $loss < $cost) { ($best, $cost) = ($candidate, $loss) }
        }
    }
    my @warnings;
    push @warnings,
        {
        code    => 'CW_W_TIMING_AMBIGUOUS',
        message => 'Single mark length cannot distinguish dots from dashes'
        }
        if defined($best) && $on[-1] / $on[0] < 1.5;
    return ($best, \@warnings);
}

sub _mark {
    my ($ratio, $warnings) = @_;
    if ($ratio < 0.45 || $ratio > 4.5 || ($ratio > 1.6 && $ratio < 2.3)) {
        push @{$warnings}, {code => 'CW_W_TIMING', message => 'Mark outside timing tolerance'};
        return '?';
    }
    return $ratio < 2 ? '.' : '-';
}

sub _groups {
    my ($segments, $dot, $spacing, $complete, $warnings) = @_;
    my @groups;
    my $pending = '';
    for my $i (0 .. $#{$segments}) {
        my $segment = $segments->[$i];
        if ($segment->{state} eq 'on') {
            $pending .= _mark($segment->{duration} / $dot, $warnings);
            next;
        }
        next if !length($pending) || $segment->{duration} < 2 * $dot;
        next if !$complete && $i == $#{$segments};
        push @groups, $pending;
        $pending = '';
        push @groups, '/' if $segment->{duration} >= 5 * $spacing;
    }
    push @groups, $pending if $complete && length $pending;
    pop @groups if @groups && $groups[-1] eq '/';
    return \@groups;
}

sub _translate {
    my ($self, $groups, $warnings) = @_;
    my $text = '';
    for my $group (@{$groups}) {
        if ($group eq '/') { $text .= ' '; next }
        my $decoded = eval { $self->decode($group) };
        if ($@) {
            $text .= "\x{FFFD}";
            push @{$warnings},
                {code => 'CW_W_SYMBOL', message => 'Unrecognized or ambiguous mark group'};
        }
        else { $text .= $decoded }
    }
    return $text;
}

sub _snapshot {
    my ($self, $complete) = @_;
    my $events = {
        segments => $self->{segments},
        ($self->{kind} // 'duration') eq 'samples' ? (sample_rate => $self->{rate}) : (unit => 'us')
    };
    my $timed = ($self->{kind} // '') eq 'samples' ? to_timed($events) : $events;
    my ($dot, $warnings) =
        defined($self->{wpm}) ? (1_200_000 / $self->{wpm}, []) : _estimate_dot($timed->{segments});
    return Ham::CW::Result->new(
        complete => $complete,
        events   => $events,
        warnings => [{code => 'CW_W_NO_TIMING', message => 'No usable timing evidence'}]
    ) unless $dot;
    my $spacing = $dot;
    if (defined($self->{effective_wpm})) {
        my $character_wpm = 1_200_000 / $dot;
        if (!defined($self->{wpm}) && $self->{effective_wpm} > $character_wpm * (1 + 1e-9)) {
            push @{$warnings},
                {
                code    => 'CW_W_SPACING_AMBIGUOUS',
                message => 'effective_wpm exceeds estimated character speed; using ordinary spacing'
                };
        }
        else {
            $spacing = (60_000_000 / $self->{effective_wpm} - 31 * $dot) / 19;
            $spacing = $dot if $spacing < $dot;
        }
    }
    else {
        # Recording margins and isolated operator pauses do not establish
        # Farnsworth spacing. Require repeated stretched gaps between marks.
        my @gaps;
        my $segments = $timed->{segments};
        for my $i (1 .. $#{$segments} - 1) {
            next
                unless $segments->[$i]{state} eq 'off'
                && $segments->[$i - 1]{state} eq 'on'
                && $segments->[$i + 1]{state} eq 'on';
            push @gaps, $segments->[$i]{duration} / $dot;
        }
        my $long = grep { $_ > 8 } @gaps;
        if ($long >= 2) {
            push @{$warnings},
                {
                code    => 'CW_W_SPACING_AMBIGUOUS',
                message =>
                    'Repeated long internal gaps may be Farnsworth spacing; specify effective_wpm'
                };
        }
    }
    my $groups = _groups($timed->{segments}, $dot, $spacing, $complete, $warnings);
    my $text   = $self->_translate($groups, $warnings);
    return Ham::CW::Result->new(
        text        => $text,
        morse       => join(' ', @{$groups}),
        events      => $events,
        wpm         => 1_200_000 / $dot,
        complete    => $complete,
        warnings    => $warnings,
        diagnostics => {
            dot_us        => $dot,
            timing_source => defined($self->{wpm}) ? 'configured' : 'estimated'
        }
    );
}

sub result {
    my ($self) = @_;
    return $self->{final} // ($self->{snapshot} //= $self->_snapshot(0));
}

sub finish {
    my ($self) = @_;
    return $self->{final} if $self->{state} eq 'FINISHED';
    my $result = $self->_snapshot(1);
    $self->{final}    = $result;
    $self->{snapshot} = undef;
    $self->{state}    = 'FINISHED';
    return $result;
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Decoder - decode Morse notation and incremental keying events

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Ham::CW::Encoder;
    use Ham::CW::Decoder;

    my $decoder = Ham::CW::Decoder->new(wpm => 20);
    print $decoder->decode('... --- ...'), "\n";  # SOS
    my $events = Ham::CW::Encoder->new(wpm => 20)->events('SOS');
    $decoder->feed($events);
    my $result = $decoder->finish;
    print $result->text, "\n";

=head1 DESCRIPTION

The C<decode> method translates textual dots/dashes strictly. Event decoding
uses C<feed>, C<result> and C<finish> and returns diagnostic snapshots.
These are separate operations: C<decode> neither consumes nor resets event
history. This class does not analyze audio; use L<Ham::CW::Detector> for that.

=head1 METHODS

=head2 new

    my $decoder = Ham::CW::Decoder->new(%options);

Returns a decoder in C<READY>. Options:

=over 4

=item * C<wpm>: optional character speed, finite number 1..200. Omitted/undefined means estimate from events, within 5..60 WPM.

=item * C<effective_wpm>: optional spacing speed, finite number 1..WPM when WPM is explicit, otherwise 1..200. Omitted/undefined uses ordinary spacing.

=item * C<prefer_prosigns>: false by default; set to 1 to prefer operational tokens for shared waveforms.

=item * C<max_segments>: 100000; integer 1..1000000, limiting retained canonical event runs after cross-feed joins.

=back

Unknown/duplicate options and invalid ranges raise C<CW_E_ARGUMENT>.
If explicit effective speed exceeds explicit character speed, construction
fails. A mismatch against an estimated speed instead warns and uses ordinary
spacing, so observations do not cause an argument exception during finish.

=head2 decode

    my $text = $decoder->decode($morse);

Returns decoded text. Whitespace separates Morse characters; C</> separates
words, with optional surrounding whitespace. Leading/trailing whitespace is
ignored. Empty/whitespace-only input returns an empty string. Undefined input
or references raise C<CW_E_ARGUMENT>. Invalid syntax or unknown groups raise
C<CW_E_SYMBOL>; no partial string is returned for a strict decoding failure.
This method remains usable independently of the event lifecycle.

=head2 feed

    $decoder->feed($events);

Validates and copies a TimedEvents or SampledEvents block; returns the object.
Each block must satisfy L<Ham::CW::Events>. Units and, for sampled events,
sample rate must remain constant across feeds. Adjacent equal states at a
block boundary are joined. Total retained runs must fit C<max_segments> and
cumulative duration must not exceed C<2**52> input units.

An accepted feed sets C<ACTIVE> and invalidates cached previews. A validation
failure preserves history and state. Feeding after finish raises
C<CW_E_STATE>. Calls are cumulative; the method returns no incremental text.

=head2 result

    my $preview = $decoder->result;

Returns a cumulative L<Ham::CW::Result>. Before finish it is provisional and
C<complete> is 0. A final still-open gap does not confirm its preceding letter;
more evidence or finish is needed. Automatic timing and earlier text may
change as more data arrives. Unchanged snapshots are cached, and their
reference-valued accessors still return copies. After finish, this returns
the finalized Result.

=head2 finish

    my $final = $decoder->finish;

Confirms the pending final group, returns a complete Result and sets
C<FINISHED>. Repeated calls return the cached final Result. No additional
silence is inserted. Completion does not imply reliable decoding.

=head2 reset

    $decoder->reset;

Discards events and cached snapshots, preserves configuration, restores
C<READY> and returns the object. Earlier Result objects remain independent.

=head2 state

    my $state = $decoder->state;

Returns C<READY>, C<ACTIVE> or C<FINISHED>.

=head1 TIMING AND UNCERTAINTY

Without WPM, mark durations are fitted to one-dot and three-dot lengths.
Only one observed mark length cannot distinguish dots from dashes; the Result
contains C<CW_W_TIMING_AMBIGUOUS>. Supply WPM for short or repetitive input.

Farnsworth word boundaries need C<effective_wpm>. At least two internal gaps
longer than eight dots produce C<CW_W_SPACING_AMBIGUOUS> when spacing speed
is absent. Leading/trailing recording silence and isolated long pauses do
not trigger that heuristic. Absence of a warning does not prove ordinary
spacing. When effective speed exceeds an estimated character speed, the same
warning code reports fallback to ordinary spacing.

An implausible mark is represented as C<?> in the Result's Morse notation.
An unrecognized group becomes U+FFFD in text, with warnings. Other decoded
groups are retained. Use an appropriate text output encoding when displaying
replacement or accented characters. L<Ham::CW::Result/WARNINGS> lists codes.

=head1 SHARED WAVEFORMS

The original spelling of a shared signal cannot be recovered from events or
Morse notation. Decoding chooses these representations:

    Waveform  Default  prefer_prosigns => 1
    .-.-.     +        <AR>
    -...-     =        <BT>
    -.--.     (        <KN>
    -.-.-     <CT>     <KA>
    ...-.     <SN>     <VE>

Other supported prosigns decode to their explicit angle-bracket tokens.
See L<Ham::CW::Encoder/SYMBOLS> for accepted text and prosigns.

=head1 ERRORS

Invalid input/rate/options raise C<CW_E_ARGUMENT>; strict textual failures
raise C<CW_E_SYMBOL>; invalid event alternation/resolution raises
C<CW_E_TIMING>; history/duration limits raise C<CW_E_RESOURCE>.
Event timing uncertainty produces Result warnings, not argument exceptions.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
