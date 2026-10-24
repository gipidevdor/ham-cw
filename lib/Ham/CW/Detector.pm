package Ham::CW::Detector;
use 5.020;
use strict;
use warnings;
use Ham::CW::_Internal::Validate qw(fail number integer options samples named_arguments);
use Ham::CW::Decoder;
use Ham::CW::Result;
use Ham::CW::_Internal::Backend;
our $VERSION = '0.001';
my $PI = 4 * atan2(1, 1);

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args,
        qw(sample_rate frequency min_frequency max_frequency frequency_step wpm effective_wpm max_frames min_contrast min_purity backend)
    );
    my $rate         = integer('sample_rate', $args{sample_rate} // 16000, 1000, 384000);
    my $default_high = $rate / 2 - 1 < 1500 ? $rate / 2 - 1 : 1500;
    my $low  = number('min_frequency',  $args{min_frequency} // 300,           1,    $rate / 2 - 1);
    my $high = number('max_frequency',  $args{max_frequency} // $default_high, $low, $rate / 2 - 1);
    my $step = number('frequency_step', $args{frequency_step} // 50,           10,   500);
    my @frequencies;

    if (defined $args{frequency}) {
        @frequencies = (number('frequency', $args{frequency}, 1, $rate / 2 - 1));
    }
    else {
        for (my $f = $low; $f <= $high; $f += $step) { push @frequencies, $f }
    }
    fail('CW_E_RESOURCE', 'Too many frequency candidates') if @frequencies > 256;
    number('wpm', $args{wpm}, 1, 60) if defined $args{wpm};
    number('effective_wpm', $args{effective_wpm}, 1, $args{wpm} // 60)
        if defined $args{effective_wpm};
    my $self = bless {
        %args,
        sample_rate  => $rate,
        backend      => Ham::CW::_Internal::Backend::resolve($args{backend}),
        frequencies  => \@frequencies,
        frame_size   => int($rate * 0.005 + 0.5),
        max_frames   => integer('max_frames', $args{max_frames} // 24000, 1, 1000000),
        min_contrast => number('min_contrast', $args{min_contrast} // 0.60, 0.01, 1),
        min_purity   => number('min_purity',   $args{min_purity}   // 0.20, 0.01, 1)
    }, $class;
    my $n = $self->{frame_size};
    $self->{window}       = [map { 0.5 - 0.5 * cos(2 * $PI * $_ / ($n - 1)) } 0 .. $n - 1];
    $self->{coefficients} = [map { 2 * cos(2 * $PI * $_ / $rate) } @frequencies];
    return $self->reset;
}

sub reset {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($self) = @_;
    $self->{state}         = 'READY';
    $self->{buffer}        = [];
    $self->{frames}        = [];
    $self->{total_samples} = 0;
    $self->{final}         = undef;
    $self->{snapshot}      = undef;
    $self->{pdl_kernels}   = {};
    return $self;
}
sub state { my ($self) = @_; return $self->{state} }    ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub _frame {
    my ($self, $block) = @_;
    if ($self->{backend} eq 'pdl') {
        Ham::CW::_Internal::PDL::frames($self, [$block]);
        return;
    }
    my $n    = @{$block};
    my $mean = 0;
    $mean += $_ for @{$block};
    $mean /= $n;
    my (@windowed, $energy);
    $energy = 0;
    for my $i (0 .. $n - 1) {
        my $x = ($block->[$i] - $mean) * $self->{window}[$i];
        push @windowed, $x;
        $energy += $x * $x;
    }
    my @powers;
    for my $coeff (@{$self->{coefficients}}) {
        my ($s1, $s2) = (0, 0);
        for my $x (@windowed) { my $s = $x + $coeff * $s1 - $s2; $s2 = $s1; $s1 = $s }
        my $power = $s1 * $s1 + $s2 * $s2 - $coeff * $s1 * $s2;
        push @powers, $power > 0 ? $power : 0;
    }
    push @{$self->{frames}}, {powers => \@powers, energy => $energy, samples => $n};
    return;
}

sub feed {
    my ($self, $block) = @_;
    fail('CW_E_STATE', 'Detector is finalized') if $self->{state} eq 'FINISHED';
    samples($block, 1000000);
    my $future = @{$self->{frames}} +
        int((@{$self->{buffer}} + @{$block} + $self->{frame_size} - 1) / $self->{frame_size});
    fail('CW_E_RESOURCE',
        'Detector frame limit exceeded; increase max_frames or decode a shorter recording')
        if $future > $self->{max_frames};
    $self->{snapshot} = undef;
    $self->{total_samples} += @{$block};
    my $offset = 0;

    while ($offset < @{$block}) {
        if (   $self->{backend} eq 'pdl'
            && !@{$self->{buffer}}
            && @{$block} - $offset >= $self->{frame_size})
        {
            my $count = int((@{$block} - $offset) / $self->{frame_size});
            $count = 128 if $count > 128;
            my @blocks;
            for (1 .. $count) {
                push @blocks, [@{$block}[$offset .. $offset + $self->{frame_size} - 1]];
                $offset += $self->{frame_size};
            }
            Ham::CW::_Internal::PDL::frames($self, \@blocks);
            next;
        }
        my $take = $self->{frame_size} - @{$self->{buffer}};
        $take = @{$block} - $offset if $take > @{$block} - $offset;
        push @{$self->{buffer}}, @{$block}[$offset .. $offset + $take - 1];
        $offset += $take;
        if (@{$self->{buffer}} == $self->{frame_size}) {
            $self->_frame($self->{buffer});
            $self->{buffer} = [];
        }
    }
    $self->{state} = 'ACTIVE';
    return $self;
}

sub _select_tone {
    my ($self, $frames) = @_;
    my @totals = (0) x @{$self->{frequencies}};
    for my $frame (@{$frames}) {
        $totals[$_] += $frame->{powers}[$_] for 0 .. $#totals;
    }
    my $best = 0;
    for my $i (1 .. $#totals) { $best = $i if $totals[$i] > $totals[$best] }
    my @powers = map { $_->{powers}[$best] } @{$frames};
    return ($best, \@powers);
}

sub _purity {
    my ($self, $frames, $powers, $peak) = @_;
    my ($inband, $broadband) = (0, 0);
    for my $i (0 .. $#{$frames}) {
        next if $powers->[$i] < 0.25 * $peak;
        $inband    += $powers->[$i] * 2 / $self->{frame_size};
        $broadband += $frames->[$i]{energy};
    }
    my $purity = $broadband ? $inband / $broadband : 0;
    return $purity;
}

sub _key_state {
    my ($tracker, $power) = @_;
    my $limited = $power < 2 * $tracker->{ceiling} ? $power : 2 * $tracker->{ceiling};
    my $decayed = $tracker->{peak} * $tracker->{decay};
    $tracker->{peak} = $limited > $decayed ? $limited : $decayed;
    $tracker->{peak} = $tracker->{minimum} if $tracker->{peak} < $tracker->{minimum};
    my $fraction  = $tracker->{state} eq 'on' ? 0.06 : 0.12;
    my $threshold = $tracker->{noise} + ($tracker->{peak} - $tracker->{noise}) * $fraction;
    $tracker->{state} = $power >= $threshold ? 'on' : 'off';

    if ($tracker->{state} eq 'off') {
        $tracker->{noise} += 0.02 * ($power - $tracker->{noise});
    }
    return $tracker->{state};
}

sub _segment {
    my ($self, $frames, $powers, $floor, $peak) = @_;
    my @segments;
    my $minimum = $floor + 0.05 * ($peak - $floor);
    my $tracker = {
        state   => 'off',
        noise   => $floor,
        peak    => $minimum,
        minimum => $minimum,
        ceiling => $peak,
        decay   => exp(-$self->{frame_size} / $self->{sample_rate}),
    };
    for my $i (0 .. $#{$frames}) {
        my $state = _key_state($tracker, $powers->[$i]);
        if (@segments && $segments[-1]{state} eq $state) {
            $segments[-1]{samples} += $frames->[$i]{samples};
        }
        else { push @segments, {state => $state, samples => $frames->[$i]{samples}} }
    }

    # Remove isolated runs below 10 ms only when bounded by the same state.
    for (my $i = 1; $i < $#segments; ++$i) {
        if ($segments[$i]{samples} < 0.010 * $self->{sample_rate}) {
            $segments[$i - 1]{samples} += $segments[$i]{samples} + $segments[$i + 1]{samples};
            splice @segments, $i, 2;
            $i -= 2;
            $i = 0 if $i < 0;
        }
    }
    return \@segments;
}

sub _robust_peak {
    my ($powers) = @_;
    my $peak = 0;

    # A 5 ms impulse can straddle two frames. The median of five retains
    # 20 ms dots while excluding either alignment of an isolated impulse.
    for my $i (0 .. $#{$powers}) {
        my @local = sort { $a <=> $b }
            map { $_ < 0 || $_ > $#{$powers} ? 0 : $powers->[$_] } $i - 2 .. $i + 2;
        $peak = $local[2] if $local[2] > $peak;
    }
    return $peak;
}

sub _analyze {
    my ($self, $complete) = @_;
    my @frames = @{$self->{frames}};
    my $empty  = sub {
        my ($code, $message, $diagnostics) = @_;
        return Ham::CW::Result->new(
            complete    => $complete,
            events      => {sample_rate => $self->{sample_rate}, segments => []},
            warnings    => [{code => $code, message => $message}],
            diagnostics => $diagnostics // {}
        );
    };
    return $empty->('CW_W_NO_SIGNAL', 'No usable audio frames') unless @frames;
    my ($best, $powers) = $self->_select_tone(\@frames);
    my @powers = @{$powers};
    my @sorted = sort { $a <=> $b } @powers;

    my $peak = _robust_peak(\@powers);
    return $empty->('CW_W_NO_SIGNAL', 'Signal below energy floor') if $peak < 1e-10;
    my $floor    = $sorted[int($#sorted * 0.10)];
    my $contrast = ($peak - $floor) / $peak;
    return $empty->('CW_W_NOT_CW', 'No keyed envelope contrast', {contrast => $contrast})
        if $contrast < $self->{min_contrast};
    my $purity = $self->_purity(\@frames, \@powers, $peak);
    return $empty->('CW_W_NOT_CW', 'Insufficient narrow-band energy', {purity => $purity})
        if $purity < $self->{min_purity};
    my $segments = $self->_segment(\@frames, \@powers, $floor, $peak);
    my @marks    = grep { $_->{state} eq 'on' } @{$segments};
    return $empty->('CW_W_NOT_CW', 'Too few keyed marks to identify CW') if @marks < 3;
    my $events  = {sample_rate => $self->{sample_rate}, segments => $segments};
    my %timing  = map { defined($self->{$_}) ? ($_ => $self->{$_}) : () } qw(wpm effective_wpm);
    my $decoder = Ham::CW::Decoder->new(%timing);
    $decoder->feed($events);
    my $r = $complete ? $decoder->finish : $decoder->result;
    my $h = $r->as_hash;

    if (grep { $_->{code} eq 'CW_W_TIMING_AMBIGUOUS' } @{$h->{warnings}}) {
        $h->{text} = '';
        push @{$h->{warnings}},
            {
            code    => 'CW_W_UNRELIABLE',
            message => 'Specify WPM to resolve ambiguous mark lengths'
            };
    }
    $h->{frequency}   = $self->{frequencies}[$best];
    $h->{diagnostics} = {
        %{$h->{diagnostics}},
        purity                 => $purity,
        contrast               => $contrast,
        frame_samples          => $self->{frame_size},
        analyzed_samples       => $self->{total_samples},
        frequency_grid_step_hz => defined($self->{frequency}) ? 0 : ($self->{frequency_step} // 50)
    };
    return Ham::CW::Result->new(%{$h});
}

sub result {
    my ($self) = @_;
    return $self->{final} // ($self->{snapshot} //= $self->_analyze(0));
}

sub finish {
    my ($self) = @_;
    return $self->{final}          if $self->{state} eq 'FINISHED';
    $self->_frame($self->{buffer}) if @{$self->{buffer}};
    $self->{buffer}   = [];
    $self->{final}    = $self->_analyze(1);
    $self->{state}    = 'FINISHED';
    $self->{snapshot} = undef;
    return $self->{final};
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Detector - incremental detection of a keyed CW audio tone

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Ham::CW;
    use Ham::CW::Detector;

    my $cw = Ham::CW->new(sample_rate => 8000, frequency => 650, wpm => 20);
    my $next = $cw->stream_samples('SOS', block_size => 1024);
    my $detector = Ham::CW::Detector->new(
        sample_rate => 8000, frequency => 650, wpm => 20);
    while (my $block = $next->()) { $detector->feed($block) }
    my $result = $detector->finish;
    print $result->text, "\n";
    warn "Inspect reception warnings\n" if $result->has_warnings;

=head1 DESCRIPTION

Accepts normalized mono samples and returns cumulative decoding snapshots.
The sample rate must match the incoming audio; no resampling is performed.
For a WAV path or bytes, use L<Ham::CW/read_wav> or L<Ham::CW/decode_wav_bytes>
so the header supplies the rate.

Reception is experimental. The detector selects one tone; it does not
separate overlapping transmitters, correct large frequency drift or validate
the linguistic meaning of decoded text. Short messages may need tone/speed
hints. At least three detected keyed marks are required, so isolated E or T
cannot be identified as CW by this detector even with speed supplied.

=head1 METHODS

=head2 new

    my $detector = Ham::CW::Detector->new(%options);

Returns a detector in C<READY>. Options and inclusive ranges:

=over 4

=item * C<sample_rate>: 16000 Hz; integer 1000..384000.

=item * C<frequency>: optional known tone, 1..C<sample_rate / 2 - 1> Hz. Undefined/omitted means search the frequency grid.

=item * C<min_frequency>: 300 Hz; range 1..C<sample_rate / 2 - 1>.

=item * C<max_frequency>: the smaller of 1500 and C<sample_rate / 2 - 1> Hz; must be at least C<min_frequency> and at most C<sample_rate / 2 - 1>.

=item * C<frequency_step>: 50 Hz; range 10..500. Grid candidates start at the minimum and advance by this step without exceeding the maximum. At most 256 candidates are allowed.

=item * C<wpm>: optional explicit character speed, range 1..60. Undefined/omitted means estimate within 5..60 WPM.

=item * C<effective_wpm>: optional spacing speed, range 1..WPM when WPM is explicit, otherwise 1..60. Omitted/undefined uses ordinary spacing; specify it for Farnsworth reception.

=item * C<min_contrast>: 0.60; range 0.01..1, minimum keyed-envelope contrast.

=item * C<min_purity>: 0.20; range 0.01..1, minimum projected narrow-band energy ratio. This ratio is not normalized to 1 for a pure tone.

=item * C<max_frames>: 24000; integer 1..1000000, including frames representing recording silence.

=item * C<backend>: C<perl> (default), C<pdl> or C<auto>. See L<Ham::CW/OPTIONAL PDL BACKEND>.

=back

Frequency search settings are still validated when a known tone is given.
Other undefined optional values use defaults. Unknown/duplicate names and
invalid ranges raise C<CW_E_ARGUMENT>; too many candidates raise
C<CW_E_RESOURCE>. Explicit effective speed must not exceed explicit WPM.

=head2 feed

    $detector->feed($samples);

Accepts an array reference of finite numbers in [-1,1], at most 1000000
samples per call, and returns the object. Empty blocks are valid. Accepted
feeds set C<ACTIVE> and invalidate the preview cache. Validation/resource
errors preserve history, buffer and state. Feed after finish raises
C<CW_E_STATE>.

Frames have C<int(sample_rate * 0.005 + 0.5)> samples, approximately 5 ms.
A partial frame is carried between feeds; chunk boundaries do not change the
frame grid. Raw audio retention is limited to this partial frame, but frame
powers are retained for the entire accepted recording up to C<max_frames>.
A pending partial frame also counts against that limit.

=head2 result

    my $preview = $detector->result;

Returns a provisional L<Ham::CW::Result> with C<complete> 0 without flushing
the partial frame. It analyzes all retained complete frames. Earlier text,
tone, timing and diagnostics may change after more audio. Unchanged previews
are cached. After finish, this returns the cached final Result.

=head2 finish

    my $final = $detector->finish;

Processes any partial frame once, finalizes decoding, sets C<FINISHED> and
returns a complete Result. Repeated calls return the cached Result. No-signal
or uncertain input can still finish successfully with empty text and warnings.

=head2 reset

    $detector->reset;

Discards audio features, partial input, progress and snapshots; preserves
configuration, restores C<READY> and returns the object. Previous Results
remain independent.

=head2 state

    my $state = $detector->state;

Returns C<READY>, C<ACTIVE> or C<FINISHED>.

=head1 ANALYSIS AND DIAGNOSTICS

Frames are DC-removed and Hann-windowed. The Perl backend uses a Goertzel
bank; PDL uses equivalent sinusoidal projections. Accumulated candidate
energy chooses a tone. A lower percentile seeds the noise floor, while the
peak seed uses the maximum of a five-frame median to reduce sensitivity to
isolated 5 ms impulses without excluding sparse messages.

Segmentation tracks keyed peaks with one-second decay, updates noise during
OFF frames and uses hysteresis. Short interior runs are merged before event
decoding. This does not guarantee rejection of every kind of interference.

C<contrast> is C<(peak - floor) / peak>. C<purity> compares projected tone
energy with windowed broadband energy; a well-resolved matched pure tone is
approximately 0.67, not 1. C<frequency_grid_step_hz> reports candidate spacing
(0 for a supplied tone), not frequency accuracy or filter bandwidth. The
short analysis window has broad response, roughly 300 Hz full half-power
bandwidth; nearby tones are not independently resolved by a 50 Hz grid.
L<Ham::CW::Result/diagnostics> describes the other diagnostic fields.

=head1 LIMITS AND WARNINGS

Maximum retained seconds are approximately
C<max_frames * frame_samples / sample_rate>, about 120 seconds by default.
Increase C<max_frames> explicitly for longer recordings and budget more
memory. Large arrays have their own per-feed limit. Streaming input does not
make this an unlimited-duration receiver.

The design targets reasonably stable, isolated CW and mark lengths of about
20 ms or longer. Severe fading, sustained static, competing tones and unknown
Farnsworth spacing can cause wrong, partial or empty text. Field accuracy on
off-air recordings has not been established by the synthetic tests.

A single-length mark pattern remains ambiguous without WPM; the detector
suppresses its guessed text and reports warnings. Individual damaged groups
otherwise use replacement characters while retaining other text. Review
L<Ham::CW::Result/WARNINGS>; completion is not a confidence estimate.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
