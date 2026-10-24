package Ham::CW::Generator;
use 5.020;
use strict;
use warnings;
use Ham::CW::Events              qw(validate_events to_samples);
use Ham::CW::_Internal::Validate qw(fail number integer options named_arguments);
our $VERSION = '0.001';
my $PI = 4 * atan2(1, 1);

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(sample_rate frequency amplitude attack_ms release_ms max_samples));
    my $rate = integer('sample_rate', $args{sample_rate} // 16000, 1000, 384000);
    my $self = bless {
        sample_rate => $rate,
        frequency   => number('frequency',  $args{frequency}  // 700, 1, $rate / 2 - 1),
        amplitude   => number('amplitude',  $args{amplitude}  // 0.8, 0, 1),
        attack_ms   => number('attack_ms',  $args{attack_ms}  // 5,   0, 1000),
        release_ms  => number('release_ms', $args{release_ms} // 5,   0, 1000),
        max_samples => integer('max_samples', $args{max_samples} // 10000000, 1, 100000000),
    }, $class;
    return $self->reset;
}

sub reset {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($s) = @_;
    $s->{position} = 0;
    $s->{state}    = 'READY';
    $s->{produced} = 0;
    return $s;
}
sub state { my ($self) = @_; return $self->{state} }    ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub stream {
    my ($self, $events, $block_size) = @_;
    integer('block_size', $block_size //= 4096, 1, 1000000);
    fail('CW_E_STATE', 'Reset generator before starting another stream')
        unless $self->{state} eq 'READY';
    my $field   = validate_events($events);
    my $sampled = $field eq 'duration' ? to_samples($events, $self->{sample_rate}) : $events;
    fail('CW_E_ARGUMENT', 'Sample rate mismatch')
        unless $sampled->{sample_rate} == $self->{sample_rate};
    my @segments = map { +{%{$_}} } @{$sampled->{segments}};
    my ($si, $offset, $absolute) = (0, 0, 0);
    my $total = 0;
    $total += $_->{samples} for @segments;
    fail('CW_E_RESOURCE', 'Generation exceeds max_samples') if $total > $self->{max_samples};
    $self->{state} = 'ACTIVE';
    my $generation = ++$self->{generation};
    return sub {
        fail('CW_E_STATE', 'Generator stream was reset or replaced')
            if $generation != ($self->{generation} // 0) || $self->{state} eq 'READY';
        if ($si > $#segments) { $self->{state} = 'FINISHED'; return }
        my @out;
        while (@out < $block_size && $si <= $#segments) {
            my $seg   = $segments[$si];
            my $value = 0;
            if ($seg->{state} eq 'on') {
                my $attack  = $self->{attack_ms} * $self->{sample_rate} / 1000;
                my $release = $self->{release_ms} * $self->{sample_rate} / 1000;
                $attack  = $seg->{samples} / 2 if $attack > $seg->{samples} / 2;
                $release = $seg->{samples} / 2 if $release > $seg->{samples} / 2;
                my $gain = 1;
                $gain *= 0.5 * (1 - cos($PI * $offset / $attack)) if $attack && $offset < $attack;
                my $remaining_mark = $seg->{samples} - 1 - $offset;
                $gain *= 0.5 * (1 - cos($PI * $remaining_mark / $release))
                    if $release && $remaining_mark < $release;
                my $cycles = $absolute * $self->{frequency} / $self->{sample_rate};
                my $phase  = 2 * $PI * ($cycles - int($cycles));
                $value = $self->{amplitude} * $gain * sin($phase);
            }
            push @out, $value;
            ++$absolute;
            if (++$offset == $seg->{samples}) { ++$si; $offset = 0 }
        }
        $self->{produced} = $absolute;
        $self->{state}    = 'FINISHED' if $si > $#segments;
        return \@out;
    };
}

sub generate {
    my ($self, $events) = @_;
    my $next = $self->stream($events);
    my @out;
    while (my $block = $next->()) { push @out, @{$block} }
    return \@out;
}

sub result {
    my ($self) = @_;
    return {
        state       => $self->{state},
        samples     => $self->{produced},
        sample_rate => $self->{sample_rate}
    };
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Generator - deterministic, block-independent sinusoidal synthesis

=head1 METHODS

C<new> accepts C<sample_rate> (16000), C<frequency> (700 Hz, strictly below
Nyquist), C<amplitude> (0.8 in 0..1), C<attack_ms> and C<release_ms> (5 each),
and C<max_samples> (10000000). Rates are integers from 1000 to 384000.

C<stream(events, block_size)> validates and copies events, then returns an
iterator producing normalized floating-point sample arrays, or undef at EOF.
Default block size is 4096; valid sizes are 1..1000000. Samples depend on the
absolute sample index, so block boundaries do not change phase or output.
Phase advances through silence. Raised-cosine ramps remain inside each mark;
ramps are shortened for marks smaller than twice their configured duration.

C<generate(events)> collects a stream in memory. Both methods enforce the total
sample limit before output. TimedEvents are explicitly converted; SampledEvents
must match the configured rate. C<result> reports sample count and C<state>.
C<reset> starts a new generation and invalidates old iterators. States are
READY, ACTIVE and FINISHED. Consume a stream before resetting its generator.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
