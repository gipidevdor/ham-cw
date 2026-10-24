package Ham::CW::Detector;
use 5.020;
use strict;
use warnings;
use Ham::CW::_Internal::Validate qw(fail number integer options samples);
use Ham::CW::Decoder;
use Ham::CW::Result;
our $VERSION = '0.001';
my $PI = 4 * atan2(1, 1);

sub new {
    my ($class, %args) = @_;
    options(\%args,
        qw(sample_rate frequency min_frequency max_frequency frequency_step wpm effective_wpm max_frames min_contrast)
    );
    my $rate = integer('sample_rate', $args{sample_rate} // 16000, 1000, 384000);
    my $low  = number('min_frequency',  $args{min_frequency}  // 300,  1,    $rate / 2 - 1);
    my $high = number('max_frequency',  $args{max_frequency}  // 1500, $low, $rate / 2 - 1);
    my $step = number('frequency_step', $args{frequency_step} // 50,   10,   500);
    my @frequencies;
    if (defined $args{frequency}) {
        @frequencies = (number('frequency', $args{frequency}, 1, $rate / 2 - 1));
    }
    else {
        for (my $f = $low; $f <= $high; $f += $step) { push @frequencies, $f }
    }
    fail('CW_E_RESOURCE', 'Too many frequency candidates') if @frequencies > 256;
    number('wpm', $args{wpm}, 1, 200) if defined $args{wpm};
    number('effective_wpm', $args{effective_wpm}, 1, $args{wpm} // 200)
        if defined $args{effective_wpm};
    my $self = bless {
        %args,
        sample_rate  => $rate,
        frequencies  => \@frequencies,
        frame_size   => int($rate * 0.005 + 0.5),
        max_frames   => integer('max_frames', $args{max_frames}    // 24000, 1, 1000000),
        min_contrast => number('min_contrast', $args{min_contrast} // 0.20, 0.01, 1)
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
    return $self;
}
sub state { my ($self) = @_; return $self->{state} }    ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub _frame {
    my ($self, $block) = @_;
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
    fail('CW_E_STATE', 'Detector is finalized or failed') if $self->{state} =~ /FINISHED|FAILED/x;
    samples($block, 1000000);
    my $future = @{$self->{frames}} +
        int((@{$self->{buffer}} + @{$block} + $self->{frame_size} - 1) / $self->{frame_size});
    fail('CW_E_RESOURCE', 'Detector frame limit exceeded') if $future > $self->{max_frames};
    $self->{total_samples} += @{$block};
    my $offset = 0;
    while ($offset < @{$block}) {
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

sub _segment {
    my ($self, $frames, $powers, $floor, $peak) = @_;
    my ($state, @segments) = ('off');
    for my $i (0 .. $#{$frames}) {
        my $threshold = $floor + ($peak - $floor) * ($state eq 'on' ? 0.06 : 0.12);
        $state = $powers->[$i] >= $threshold ? 'on' : 'off';
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
    my $peak   = $sorted[int($#sorted * 0.95)];
    $peak = $sorted[-1] if !$peak;
    return $empty->('CW_W_NO_SIGNAL', 'Signal below energy floor') if $peak < 1e-10;
    my $floor    = $sorted[int($#sorted * 0.10)];
    my $contrast = ($peak - $floor) / $peak;
    return $empty->('CW_W_NOT_CW', 'No keyed envelope contrast', {contrast => $contrast})
        if $contrast < 0.6;
    my $purity = $self->_purity(\@frames, \@powers, $peak);
    return $empty->('CW_W_NOT_CW', 'Insufficient narrow-band energy', {purity => $purity})
        if $purity < $self->{min_contrast};
    my $segments = $self->_segment(\@frames, \@powers, $floor, $peak);
    my @marks    = grep { $_->{state} eq 'on' } @{$segments};
    return $empty->('CW_W_NOT_CW', 'Too few keyed marks to identify CW') if @marks < 3;
    my $events  = {sample_rate => $self->{sample_rate}, segments => $segments};
    my %timing  = map { defined($self->{$_}) ? ($_ => $self->{$_}) : () } qw(wpm effective_wpm);
    my $decoder = Ham::CW::Decoder->new(%timing);
    $decoder->feed($events);
    my $r = $complete ? $decoder->finish : $decoder->result;
    my $h = $r->as_hash;

    # Unknown timing groups remain diagnostic evidence, not plausible text.
    if (
        grep {
                   $_->{code} eq 'CW_W_TIMING'
                || $_->{code} eq 'CW_W_SYMBOL'
                || $_->{code} eq 'CW_W_TIMING_AMBIGUOUS'
        } @{$h->{warnings}}
        )
    {
        $h->{text} = '';
        push @{$h->{warnings}},
            {code => 'CW_W_UNRELIABLE', message => 'Timing does not support reliable decoding'};
    }
    $h->{frequency}   = $self->{frequencies}[$best];
    $h->{diagnostics} = {
        %{$h->{diagnostics}},
        purity                  => $purity,
        contrast                => $contrast,
        frame_samples           => $self->{frame_size},
        analyzed_samples        => $self->{total_samples},
        frequency_resolution_hz => defined($self->{frequency}) ? 0 : ($self->{frequency_step} // 50)
    };
    return Ham::CW::Result->new(%{$h});
}
sub result { my ($self) = @_; return $self->{final} // $self->_analyze(0) }

sub finish {
    my ($self) = @_;
    return $self->{final}                    if $self->{state} eq 'FINISHED';
    fail('CW_E_STATE', 'Detector is failed') if $self->{state} eq 'FAILED';
    $self->_frame($self->{buffer})           if @{$self->{buffer}};
    $self->{buffer} = [];
    $self->{final}  = $self->_analyze(1);
    $self->{state}  = 'FINISHED';
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

C<new> accepts C<sample_rate> (16000), optional C<frequency> and C<wpm>,
C<effective_wpm>, C<min_frequency> (300), C<max_frequency> (1500),
C<frequency_step> (50 Hz), C<min_contrast> (0.20, minimum spectral purity),
and C<max_frames> (24000, about 120 seconds). Configure a valid search band
below Nyquist, including when using low sample rates. Search grids contain
at most 256 candidates. WPM limits match L<Ham::CW::Decoder>.

C<feed(array)> validates normalized mono samples and processes fixed 5 ms
Hann-windowed, DC-removed Goertzel frames. Chunk boundaries do not affect the
frame grid. Only one pending frame of raw samples is retained. Per-frame
energies are retained up to C<max_frames>; exceeding it is a recoverable
validation error. C<result> returns a provisional cumulative snapshot without
flushing the partial frame. C<finish> flushes it once and returns the final
L<Ham::CW::Result>. C<reset> discards history; C<state> reports READY, ACTIVE or
FINISHED. Feed after finish is rejected. Invalid input does not change state.

Analysis selects the strongest candidate across frames, applies a percentile
noise floor and hysteresis, merges short interior impulses and fits Morse
timing. Spectral purity, envelope contrast and at least three keyed marks are
required. Silence, unkeyed tones and rejected timing produce structured
warnings. Frequency is a grid estimate, not a precision measurement.
Snapshot text and estimates may change as evidence arrives; use final output
for decisions. An empty result with complete true still needs warning review.

=head1 LIMITATIONS

This initial detector targets isolated, reasonably stable CW with adequate
signal-to-noise ratio and mark lengths above roughly 20 ms. It does not
separate overlapping transmitters or track large frequency drift. Percentile
thresholds are recording-wide, not a continuously adaptive radio receiver.
Severe fading, sparse marks, long leading silence and Farnsworth without
known spacing can cause rejection or ambiguity. Field performance has not
been established. No confidence probability is claimed.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
