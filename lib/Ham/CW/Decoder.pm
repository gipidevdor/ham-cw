package Ham::CW::Decoder;
use 5.020;
use strict;
use warnings;
use Storable                     qw(dclone);
use Ham::CW::Events              qw(validate_events to_timed);
use Ham::CW::_Internal::Symbols  qw(reverse_alphabet prosigns);
use Ham::CW::_Internal::Validate qw(fail number integer options named_arguments);
use Ham::CW::Result;
use Ham::CW::_Internal::Result;
use Ham::CW::_Internal::Data qw(plain_data);
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
    fail('CW_E_ARGUMENT', 'Event segments must contain plain, acyclic data, at most 64 levels deep')
        unless plain_data($events->{segments});
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

sub _fit_dot {
    my ($counts, $widths, $candidate) = @_;
    my (%total, %count);
    for my $duration (@{$widths}) {
        my $units = $duration < 2 * $candidate ? 1 : 3;
        $total{$units} += $duration * $counts->{$duration};
        $count{$units} += $counts->{$duration};
    }
    my ($dot, $offset) = ($candidate, 0);
    if ($count{1} && $count{3}) {
        my $short  = $total{1} / $count{1};
        my $long   = $total{3} / $count{3};
        my $fitted = ($long - $short) / 2;

        # Envelope shaping and frame rounding can shorten both mark classes.
        # Their separation estimates a dot without that common width offset.
        if ($fitted >= 20000 && $fitted <= 240000 && abs($short - $fitted) <= 0.25 * $fitted) {
            ($dot, $offset) = ($fitted, $short - $fitted);
        }
    }
    my $loss = 0;
    for my $duration (@{$widths}) {
        my $ratio    = ($duration - $offset) / $dot;
        my $distance = abs($ratio - 1) < abs($ratio - 3) ? abs($ratio - 1) : abs($ratio - 3);
        $loss += $counts->{$duration} * $distance * $distance;
    }
    return ($dot, $loss);
}

sub _estimate_dot {
    my ($segments) = @_;
    my %counts;
    ++$counts{$_->{duration}} for grep { $_->{state} eq 'on' } @{$segments};
    my @on = sort { $a <=> $b } keys %counts;
    return (undef, []) unless @on;

    # Sample the entire range of distinct widths, with a bounded candidate bank.
    # Repeated short marks must not crowd all dash evidence out of the fit.
    my @values = @on <= 64 ? @on : @on[map { int($_ * $#on / 63) } 0 .. 63];
    my ($best, $cost);
    for my $value (@values) {
        for my $candidate ($value, $value / 3) {
            next if $candidate < 20000 || $candidate > 240000;
            my ($dot, $loss) = _fit_dot(\%counts, \@on, $candidate);
            if (!defined($cost) || $loss < $cost) { ($best, $cost) = ($dot, $loss) }
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
        segments => [@{$self->{segments}}],
        ($self->{kind} // 'duration') eq 'samples' ? (sample_rate => $self->{rate}) : (unit => 'us')
    };
    my $timed = ($self->{kind} // '') eq 'samples' ? to_timed($events) : $events;
    my ($dot, $warnings) =
        defined($self->{wpm}) ? (1_200_000 / $self->{wpm}, []) : _estimate_dot($timed->{segments});
    return Ham::CW::_Internal::Result->from_owned(
        'Ham::CW::Result',
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
    return Ham::CW::_Internal::Result->from_owned(
        'Ham::CW::Result',
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

=head2 new

C<new> accepts optional C<wpm>, C<effective_wpm>, C<prefer_prosigns> and
C<max_segments> (100000). C<decode(morse)> strictly decodes text; spaces
separate letters, slashes separate words. Unknown groups raise C<CW_E_SYMBOL>.
By default the shared AR/plus waveform decodes as plus; set
C<prefer_prosigns> to favor operational tokens.

=head2 feed

C<feed(events)> accepts canonical TimedEvents or SampledEvents. Units and rate
must stay constant. Adjacent runs split across feeds are merged. Validation
errors preserve state. C<result> returns a cumulative L<Ham::CW::Result>;
only closed gaps confirm letters. C<finish> confirms the final group and is
idempotent. Repeated C<result> calls without a successful feed reuse the
cached snapshot; reference-valued accessors still return copies. C<reset> discards history. C<state> returns READY, ACTIVE or FINISHED.
Feeding after finalization raises C<CW_E_STATE>.

Without WPM, timing is fitted within 5..60 WPM using candidates across the
complete range of distinct mark widths. When dots and dashes are both present,
their width separation removes a bounded common envelope/quantization offset. A stream
containing only one mark length is ambiguous and produces a warning. Specify
WPM for short messages. Farnsworth requires C<effective_wpm> for dependable
word boundaries. Repeated internal gaps longer than eight dots warn about
possible unknown spacing; recording margins and isolated long pauses do not.
When effective speed exceeds an estimated character speed, reception warns
and uses ordinary spacing. Explicit incompatible speeds are rejected by C<new>.
History is retained up to C<max_segments>; sample arrays
are never retained here. Invalid mark durations and unknown groups produce
structured warnings rather than invented characters. Timing estimates are
provisional until finish.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
