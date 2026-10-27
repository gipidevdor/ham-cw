use strict;
use warnings;
use Test::More;
use Ham::CW::Detector;

# Check complex phase, not just power: acquisition rotates successive hops.
# Direct trigonometric sums are independent of the Goertzel recurrence.
my $pi = 4 * atan2(1, 1);
for my $rate (1000, 11025, 16000, 384000) {
    for my $frequency (1, $rate / 3 + 0.37, $rate / 2 - 1) {
        my $detector = Ham::CW::Detector->new(sample_rate => $rate, frequency => $frequency);
        my $hop      = $detector->{frame_size};
        my @samples  = map { 0.6 * sin(0.19 * $_) + 0.2 * cos(0.43 * $_) + 0.1 } 0 .. $hop - 1;
        my $actual   = $detector->_acquire_partial(\@samples);
        my $scale    = 1;
        $scale += abs($_) for @samples;
        for my $i (0 .. $#{$detector->{acquire_frequencies}}) {
            my $omega = 2 * $pi * $detector->{acquire_frequencies}[$i] / $rate;
            my ($real, $imaginary) = (0, 0);
            for my $n (0 .. $#samples) {
                $real      += $samples[$n] * cos($omega * $n);
                $imaginary -= $samples[$n] * sin($omega * $n);
            }
            cmp_ok(abs($actual->{real}[$i] - $real) / $scale,
                '<', 1e-8, "complex acquisition real: $rate Hz / $frequency / bin $i");
            cmp_ok(abs($actual->{imaginary}[$i] - $imaginary) / $scale,
                '<', 1e-8, "complex acquisition imaginary: $rate Hz / $frequency / bin $i");
        }
    }
}
done_testing;
