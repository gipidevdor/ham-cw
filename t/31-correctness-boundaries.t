use strict;
use warnings;
use Test::More;
use Math::BigInt;
use Ham::CW;
use Ham::CW::Events qw(to_samples to_timed);

# An independent integer oracle also covers boundaries too large for a
# direct native multiplication, and the unrounded 2**52 resource ceiling.
my $maximum = Math::BigInt->new(2)->bpow(52);
for my $rate (1000, 1001, 3712, 8000, 11025, 44100, 48000, 125000, 192000, 300000, 384000) {
    for my $sampled (0, 1) {
        my ($numerator, $denominator) = $sampled ? (1000000, $rate) : ($rate, 1000000);
        my $edge   = $maximum->copy->bmul($denominator)->bdiv($numerator);
        my @values = (1, 194, 195, 196, 500000, $maximum->copy->bdec, $maximum->copy);
        push @values, map { $edge->copy->badd($_) } -1 .. 1;
        for my $value (@values) {
            my $input = Math::BigInt->new("$value");
            next if $input->bcmp(1) < 0 || $input->bcmp($maximum) > 0;
            my $product = $input->copy->bmul($numerator);
            my ($quotient, $remainder) = $product->copy->bdiv($denominator);
            $quotient->binc if $remainder->copy->bmul(2)->bcmp($denominator) >= 0;
            my $expected_error =
                  $product->bcmp($maximum->copy->bmul($denominator)) > 0 ? 'CW_E_RESOURCE'
                : $quotient->is_zero                                     ? 'CW_E_TIMING'
                :                                                          '';
            my $field  = $sampled ? 'samples' : 'duration';
            my $events = {
                $sampled ? (sample_rate => $rate) : (unit => 'us'),
                segments => [{state => 'on', $field => 0 + $input->bstr}],
            };
            my $result = eval { $sampled ? to_timed($events) : to_samples($events, $rate) };
            my $error  = $@;
            my $label  = "$field " . $input->bstr . " at $rate Hz";

            if ($expected_error) {
                is(ref($error) ? $error->code : "$error", $expected_error, $label);
            }
            else {
                my $output = $sampled ? 'duration' : 'samples';
                is($result && $result->{segments}[0]{$output}, 0 + $quotient->bstr, $label)
                    or diag("$error");
            }
        }
    }
}

my $timed = to_timed(
    {
        sample_rate => 48000,
        segments    => [
            {state => 'on',  samples => 195},
            {state => 'off', samples => 96},
            {state => 'on',  samples => 96},
        ],
    }
);
is_deeply(
    [map { $_->{duration} } @{$timed->{segments}}],
    [4063, 2000, 2000],
    'half-up rounding preserves cumulative sample boundaries'
);
my $sampled = to_samples(
    {
        unit     => 'us',
        segments => [
            {state => 'on',  duration => 500000},
            {state => 'off', duration => 1000},
            {state => 'on',  duration => 1000},
        ],
    },
    1001
);
is_deeply(
    [map { $_->{samples} } @{$sampled->{segments}}],
    [501, 1, 1],
    'half-up rounding preserves cumulative timed boundaries'
);
eval {
    to_samples(
        {
            unit     => 'us',
            segments => [{state => 'on', duration => 500000}, {state => 'off', duration => 999},]
        },
        1001
    );
};
is(ref($@) ? $@->code : "$@",
    'CW_E_TIMING', 'a genuinely collapsed second segment is rejected after exact rounding');

for my $case (['O', 64], ['SOS', 113]) {
    my ($text, $limit) = @{$case};
    my $events = Ham::CW->new->events($text);
    my $bytes  = Ham::CW::MIDI->new->encode($events);
    cmp_ok(length($bytes), '<=', $limit, 'fixture fits its declared MIDI byte limit');
    my $bounded = eval { Ham::CW::MIDI->new(max_bytes => $limit)->encode($events) };
    is($bounded, $bytes, 'a fitting MIDI file is accepted without byte changes') or diag("$@");
}
my $notes = Ham::CW->new->events('O');
for my $case ([0, 63], [1000000, 64], [1000000000, 65], [10000000000, 66]) {
    my ($tail, $length) = @{$case};
    my $events = {unit => 'us', segments => [map { +{%{$_}} } @{$notes->{segments}}]};
    push @{$events->{segments}}, {state => 'off', duration => $tail} if $tail;
    is(length(Ham::CW::MIDI->new->encode($events)),
        $length, 'independent byte count includes the variable-length end-of-track delta');
    my $result = eval { Ham::CW::MIDI->new(max_bytes => 64)->encode($events) };
    my $error  = $@;
    if ($length <= 64) {
        is(length($result // ''), $length, 'fitting MIDI tail accepted');
    }
    else {
        is(ref($error) ? $error->code : "$error", 'CW_E_RESOURCE', 'oversized MIDI tail rejected');
    }
}

# Exercise long channel decoding without allocating a half-million DSP frames
# in every CI job. Literal 60 WPM keying is independent of the text encoder:
# eight 20 ms dots, 20 ms element gaps and 60 ms character gaps.
my @segments;
my $letters = 6251;
for my $letter (1 .. $letters) {
    push @segments, {state => 'off', samples => 60} if $letter > 1;
    for my $mark (1 .. 8) {
        push @segments, {state => 'off', samples => 20} if $mark > 1;
        push @segments, {state => 'on',  samples => 20};
    }
}
my $detector = Ham::CW::Detector->new(
    sample_rate => 1000,
    frequency   => 350,
    wpm         => 60,
    max_frames  => 500000,
);
my $result = eval { $detector->_decode_channel(\@segments, 1) };
ok($result, 'long channel decoding respects the explicit detector history budget') or diag("$@");
ok(
    $result && $result->{text} eq '<HH>' x $letters,
    'all independently keyed characters are recovered'
);
is_deeply($result && $result->{warnings}, [], 'valid long keying has no warnings');
done_testing;
