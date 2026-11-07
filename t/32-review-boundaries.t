use strict;
use warnings;
use Test::More;
use Math::BigInt;
use Ham::CW;
use Ham::CW::Events          qw(validate_events);
use Ham::CW::_Internal::Data qw(plain_data);

{

    package StringOption;
    use overload q{""} => sub { $_[0]{value} }, fallback => 1;
    sub new { return bless {value => $_[1]}, $_[0] }
}

for my $case (
    sub { Ham::CW::Encoder->new(unknown => StringOption->new('skip')) },
    sub { Ham::CW::Audio->new(stereo => StringOption->new('mix')) },
    sub {
        validate_events(
            {
                unit     => 'us',
                segments => [{state => StringOption->new('on'), duration => 60000}]
            }
        );
    }
    )
{
    eval { $case->() };
    is(ref($@) ? $@->code : "$@", 'CW_E_ARGUMENT', 'string options reject references');
}

my $output = '';
open my $handle, '>:raw', \$output or die $!;
eval { Ham::CW::Audio->new->write($handle, [0], sample_count => 999) };
is(ref($@) ? $@->code : "$@", 'CW_E_ARGUMENT', 'collecting writer rejects a supplied count');
is($output,                   '', 'invalid writer options leave caller output untouched');
close $handle or die $!;

my $shared = {value => 'shared leaf'};
$shared = [$shared, $shared] for 1 .. 16;
my $snapshot = Ham::CW::Result->new(diagnostics => {tree => $shared});
ok($snapshot, 'shared acyclic subtrees remain valid snapshot payloads');
my $copied = $snapshot->diagnostics->{tree};
$copied = $copied->[0] for 1 .. 16;
is($copied->{value}, 'shared leaf', 'shared payload is copied completely');
$copied->{value} = 'changed';
my $original = $shared;
$original = $original->[0] for 1 .. 16;
is($original->{value}, 'shared leaf', 'copy mutations preserve the original shared graph');

# Visit the shared subtree first at shallow depth, then beyond the limit.
# Memoization must not let the deeper path bypass depth validation.
my $deep = $shared;
$deep = [$deep] for 1 .. 50;
ok(!plain_data([$shared, $deep]),   'a shared shallow-first branch cannot bypass depth limits');
ok(!plain_data([$deep,   $shared]), 'shared depth checking is independent of branch order');
my $at_limit = $shared;
$at_limit = [$at_limit] for 1 .. 47;
ok(plain_data([$shared,   $at_limit]), 'shared paths at exactly the depth limit remain valid');
ok(plain_data([$at_limit, $shared]),   'valid shared depths do not depend on branch order');
my $cyclic = [$shared];
push @{$cyclic}, $cyclic;
ok(!plain_data($cyclic), 'shared subtree caching still rejects cycles');
pop @{$cyclic};

sub note_end {
    my ($bytes) = @_;

    # Header (22), tempo (7), program (3), note-on (4), then note-off delta.
    my ($offset, $value) = (36, 0);
    for (1 .. 4) {
        my $byte = ord substr($bytes, $offset++, 1);
        $value = $value * 128 + ($byte & 127);
        return $value unless $byte & 128;
    }
    die 'Invalid MIDI delta';
}

my $short_note = eval {
    Ham::CW::MIDI->new(ppqn => 1, bpm => 60000000 / 60001)->encode(
        {
            sample_rate => 1001,
            segments    => [{state => 'off', samples => 15583997929}, {state => 'on', samples => 1}]
        }
    );
};
ok(defined($short_note), 'exact rounding preserves a one-tick note after long leading silence')
    or diag("$@");
if (defined $short_note) {

    # Four-byte initial delta replaces the one-byte delta in the simple fixture.
    is(ord(substr($short_note, 39, 1)), 1, 'the preserved note lasts exactly one tick');
}

# The first case is just below a half tick, where floating multiplication
# rounds upward incorrectly. Other cases cover exact halves and large products.
for my $case (
    [1001,   60001,    1,     15583997929],
    [48000,  500000,   480,   1625],
    [384000, 1234567,  32767, 1000000000],
    [1001,   14999999, 1,     3900000000000],
    [44100,  500001,   480,   1000000000]
    )
{
    my ($rate, $tempo, $ppqn, $count) = @{$case};
    my $denominator = Math::BigInt->new($tempo)->bmul($rate);
    my $expected =
        Math::BigInt->new($count)
        ->bmul($ppqn)
        ->bmul(1000000)
        ->bmul(2)
        ->badd($denominator)
        ->bdiv($denominator->copy->bmul(2));
    my $bytes = Ham::CW::MIDI->new(ppqn => $ppqn, bpm => 60000000 / $tempo)
        ->encode({sample_rate => $rate, segments => [{state => 'on', samples => $count}]});
    is(note_end($bytes), 0 + $expected->bstr, "exact MIDI boundary at $rate Hz / $ppqn PPQN");
}

# Independent oscillator/envelope formula, including ramps longer than marks,
# fractional ramp lengths, phase across silence and one-sample blocks.
my $pi     = 4 * atan2(1, 1);
my $events = {
    sample_rate => 11025,
    segments    => [
        {state => 'off', samples => 7},
        {state => 'on',  samples => 1},
        {state => 'off', samples => 3},
        {state => 'on',  samples => 29},
        {state => 'off', samples => 11},
        {state => 'on',  samples => 400}
    ]
};
for my $ramps ([0, 0], [0.37, 1.13], [1000, 1000]) {
    my @expected;
    my $absolute = 0;
    for my $segment (@{$events->{segments}}) {
        my ($attack, $release) = map { $_ * 11025 / 1000 } @{$ramps};
        $attack  = $segment->{samples} / 2 if $attack > $segment->{samples} / 2;
        $release = $segment->{samples} / 2 if $release > $segment->{samples} / 2;
        for my $position (0 .. $segment->{samples} - 1) {
            my $gain = 1;
            $gain *= (1 - cos($pi * $position / $attack)) / 2
                if $attack && $position < $attack;
            my $remaining = $segment->{samples} - 1 - $position;
            $gain *= (1 - cos($pi * $remaining / $release)) / 2
                if $release && $remaining < $release;
            my $cycles = $absolute++ * 673.25 / 11025;
            push @expected, $segment->{state} eq 'off'
                ? 0
                : 0.7 * $gain * sin(2 * $pi * ($cycles - int($cycles)));
        }
    }
    for my $size (1, 17, 4096) {
        my $next = Ham::CW::Generator->new(
            sample_rate => 11025,
            frequency   => 673.25,
            amplitude   => 0.7,
            attack_ms   => $ramps->[0],
            release_ms  => $ramps->[1]
        )->stream($events, $size);
        my @actual;
        while (my $block = $next->()) { push @actual, @{$block} }
        is_deeply(\@actual, \@expected, "analytic shaped samples, @$ramps ms / $size block");
    }
}
done_testing;
