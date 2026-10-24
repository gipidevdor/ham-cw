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
    my $self = bless {%args, max_segments => $args{max_segments} // 100000}, $class;
    return $self->reset;
}

sub reset {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($self) = @_;
    $self->{state}          = 'READY';
    $self->{segments}       = [];
    $self->{kind}           = undef;
    $self->{rate}           = undef;
    $self->{total_duration} = 0;
    return $self;
}
sub state { my ($self) = @_; return $self->{state} }    ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub decode {
    my ($self, $morse) = @_;
    fail('CW_E_ARGUMENT', 'Morse must be a defined scalar') if !defined($morse) || ref($morse);
    $morse =~ s/\A\s+|\s+\z//gx;
    return '' unless length $morse;
    fail('CW_E_SYMBOL', 'Invalid Morse syntax')
        unless $morse =~ /\A[.\-]+(?:\s+[.\-]+)*(?:\s*\/\s*[.\-]+(?:\s+[.\-]+)*)*\z/x;
    my $reverse = reverse_alphabet();
    if ($self->{prefer_prosigns}) {
        my $p = prosigns();
        $reverse->{$p->{$_}} = "<$_>" for sort keys %{$p};
    }
    my @words;
    for my $word (split /\s*\/\s*/x, $morse) {
        my $text = '';
        for my $code (split /\s+/x, $word) {
            fail('CW_E_SYMBOL', 'Unknown Morse group') unless exists $reverse->{$code};
            $text .= $reverse->{$code};
        }
        push @words, $text;
    }
    return join ' ', @words;
}

sub feed {
    my ($self, $events) = @_;
    fail('CW_E_STATE', 'Decoder is finalized; reset before feeding')
        if $self->{state} =~ /FINISHED|FAILED/x;
    my $kind = validate_events($events);
    my $rate = $events->{sample_rate};
    fail('CW_E_ARGUMENT', 'Event units or sample rate changed')
        if defined($self->{kind})
        && ($self->{kind} ne $kind || ($kind eq 'samples' && $self->{rate} != $rate));
    fail('CW_E_RESOURCE', 'Decoder segment limit exceeded')
        if @{$self->{segments}} + @{$events->{segments}} > $self->{max_segments};
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
    $self->{kind}  = $kind;
    $self->{rate}  = $rate;
    $self->{state} = 'ACTIVE';
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
    my $spacing =
        defined($self->{effective_wpm})
        ? (60_000_000 / $self->{effective_wpm} - 31 * $dot) / 19
        : $dot;
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

sub result { my ($self) = @_; return $self->_snapshot($self->{state} eq 'FINISHED') }

sub finish {
    my ($self) = @_;
    fail('CW_E_STATE', 'Decoder is failed') if $self->{state} eq 'FAILED';
    my $result = $self->_snapshot(1);
    $self->{state} = 'FINISHED';
    return $result;
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Decoder - textual and incremental event decoding

=head1 SYNOPSIS

    my $decoder = Ham::CW::Decoder->new(wpm => 20);
    say $decoder->decode('... --- ...');
    $decoder->feed({unit => 'us', segments => [
        {state => 'on', duration => 60000},
        {state => 'off', duration => 180000},
    ]});
    my $result = $decoder->finish;

=head1 METHODS

C<new> accepts optional C<wpm>, C<effective_wpm>, C<prefer_prosigns> and
C<max_segments> (100000). C<decode(morse)> strictly decodes text; spaces
separate letters, slashes separate words. Unknown groups raise C<CW_E_SYMBOL>.
By default the shared AR/plus waveform decodes as plus; set
C<prefer_prosigns> to favor operational tokens.

C<feed(events)> accepts canonical TimedEvents or SampledEvents. Units and rate
must stay constant. Adjacent runs split across feeds are merged. Validation
errors preserve state. C<result> returns a cumulative L<Ham::CW::Result>;
only closed gaps confirm letters. C<finish> confirms the final group and is
idempotent. C<reset> discards history. C<state> returns READY, ACTIVE or FINISHED.
Feeding after finalization raises C<CW_E_STATE>.

Without WPM, timing is fitted to 1:3 mark lengths within 5..60 WPM. A stream
containing only one mark length is ambiguous and produces a warning. Specify
WPM for short messages. Farnsworth requires C<effective_wpm> for dependable
word boundaries. History is retained up to C<max_segments>; sample arrays
are never retained here. Invalid mark durations and unknown groups produce
structured warnings rather than invented characters. Timing estimates are
provisional until finish.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
