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

Ham::CW::Detector - bounded Goertzel CW detector

=head1 SYNOPSIS

    my $detector = Ham::CW::Detector->new(sample_rate => 16000);
    $detector->feed($normalized_mono_samples);
    my $result = $detector->finish;

=head1 METHODS

=head2 new

C<new> also accepts C<backend>: C<perl> (default), C<pdl> (requires PDL
2.081 or later), or C<auto> (PDL when available, otherwise Perl). Public
arrays, limits and lifecycle remain unchanged. See L<Ham::CW> for PDL usage.

C<new> accepts C<sample_rate> (16000), optional C<frequency> and C<wpm>,
C<effective_wpm>, C<min_frequency> (300), C<max_frequency> (1500),
C<frequency_step> (50 Hz), C<min_contrast> (0.60, minimum envelope contrast),
C<min_purity> (0.20, minimum spectral purity),
and C<max_frames> (24000, about 120 seconds). Configure a valid search band
below Nyquist; the default upper edge is clipped below Nyquist for low rates. Search grids contain
at most 256 candidates. Reception accepts explicit WPM from 1 to 60; automatic estimation covers 5..60.
The encoder and event decoder also support higher speeds.

=head2 feed

C<feed(array)> validates normalized mono samples and processes fixed 5 ms
Hann-windowed, DC-removed Goertzel frames. Chunk boundaries do not affect the
frame grid. Only one pending frame of raw samples is retained. Per-frame
energies are retained up to C<max_frames>; exceeding it is a recoverable
validation error. C<result> returns a provisional cumulative snapshot without
flushing the partial frame. Repeated snapshots are cached until a successful
feed or reset; reference-valued accessors still return copies. C<finish> flushes it once and returns the final
L<Ham::CW::Result>. C<reset> discards history; C<state> reports READY, ACTIVE or
FINISHED. Feed after finish is rejected. Invalid input does not change state.

Analysis selects the strongest candidate across frames and seeds a noise floor
from percentiles. Its peak seed is the maximum of a five-frame median,
which retains sparse marks without letting a single 5 ms impulse set the scale. Segmentation tracks signal peaks with a one-second decay,
updates the noise estimate during OFF frames, and applies hysteresis. A bounded
peak update limits the influence of impulses. It merges short interior impulses and fits Morse
timing. Spectral purity, envelope contrast and at least three keyed marks are
required. Silence, unkeyed tones and rejected timing produce structured
warnings. Frequency is a grid estimate, not a precision measurement.
C<frequency_grid_step_hz> is the candidate spacing, not spectral resolution.
The 5 ms Hann window has a bandwidth of roughly 300 Hz. Spectral purity
is the ratio of projected tone energy to windowed broadband energy; a pure
matched tone is approximately 0.67, not 1.
Snapshot text and estimates may change as evidence arrives; use final output
for decisions. An empty result with complete true still needs warning review.

=head1 LIMITATIONS

This initial detector targets isolated, reasonably stable CW with adequate
signal-to-noise ratio and mark lengths above roughly 20 ms. It does not
separate overlapping transmitters or track large frequency drift. Candidate
selection and threshold seeds use the retained recording; envelope tracking
adapts within that recording. Reception remains limited to the configured history.
Severe fading, sparse marks, long leading silence and Farnsworth without
known spacing can cause rejection or ambiguity. Field performance has not
been established. No confidence probability is claimed.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
