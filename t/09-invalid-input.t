use strict;
use warnings;
use Test::More;
use Ham::CW;
use Ham::CW::Events              qw(validate_events to_samples to_timed);
use Ham::CW::_Internal::Validate qw(samples);

sub error_is {
    my ($code, $action, $name) = @_;
    my $ok = eval { $action->(); 1 };
    ok(!$ok, $name);
    isa_ok($@, 'Ham::CW::Error');
    is((ref($@) ? (ref($@) ? $@->code : "$@") : "$@"), $code, 'stable error code') if ref($@);
}
for my $input (undef, [], {}) {
    error_is('CW_E_ARGUMENT', sub { Ham::CW->new->encode($input) }, 'text type validation');
    error_is('CW_E_ARGUMENT', sub { Ham::CW->new->decode($input) }, 'Morse type validation');
}
for my $e (
    undef, [], {},
    {unit => 'us', segments => {}},
    {unit => 'us', segments => [undef]},
    {unit => 'us', segments => [{state => 'on', duration => 1.5}]}
    )
{
    error_is('CW_E_ARGUMENT', sub { validate_events($e) }, 'event shape validation');
}
error_is(
    'CW_E_ARGUMENT',
    sub { to_samples({sample_rate => 8000, segments => []}, 8000) },
    'explicit conversion direction'
);
error_is(
    'CW_E_ARGUMENT',
    sub { to_timed({unit => 'us', segments => []}) },
    'explicit reverse direction'
);
error_is(
    'CW_E_RESOURCE',
    sub { to_timed({sample_rate => 1000, segments => [{state => 'on', samples => 2**52}]}) },
    'conversion overflow'
);
for my $args ({wpm => 1.5, unknown => 'replace'}, {wpm => 'NaN'}, {wpm => []}) {
    error_is(
        'CW_E_ARGUMENT',
        sub { Ham::CW::Encoder->new(%{$args}) },
        'encoder policy or numeric validation'
    );
}
is(Ham::CW::Encoder->new(unknown => 'skip')->encode('! !'), '', 'skip-only input');
error_is('CW_E_ARGUMENT', sub { samples({},        2) }, 'sample container type');
error_is('CW_E_RESOURCE', sub { samples([0, 0, 0], 2) }, 'sample block bound');
for my $bad (undef, {}, 'Inf', -1.01, 1.01) {
    error_is(
        'CW_E_ARGUMENT',
        sub { Ham::CW::Detector->new->feed([$bad]) },
        'sample value validation'
    );
}
error_is(
    'CW_E_ARGUMENT',
    sub { Ham::CW::Generator->new(sample_rate => 16000.5) },
    'integer sample rate'
);
error_is(
    'CW_E_ARGUMENT',
    sub { Ham::CW::Generator->new->generate({sample_rate => 8000, segments => []}) },
    'generator rate mismatch'
);
my $g = Ham::CW::Generator->new;
is_deeply($g->generate({unit => 'us', segments => []}), [], 'empty generator');
is_deeply(
    $g->result,
    {state => 'FINISHED', samples => 0, sample_rate => 16000},
    'generator statistics'
);
error_is('CW_E_ARGUMENT', sub { Ham::CW::Audio->new(stereo => 'sum') }, 'stereo policy validation');
error_is('CW_E_ARGUMENT', sub { Ham::CW::Audio->new->reader(undef) },   'reader handle validation');
error_is(
    'CW_E_ARGUMENT',
    sub { Ham::CW::MIDI->new->write(undef, {unit => 'us', segments => []}) },
    'MIDI handle validation'
);
my $bytes = '';
open my $fh, '>', \$bytes or die $!;
error_is(
    'CW_E_ARGUMENT',
    sub { Ham::CW::Audio->new->writer($fh, sample_count => 1, bits => 32) },
    'unsupported output depth'
);
error_is(
    'CW_E_RESOURCE',
    sub { Ham::CW::Audio->new(max_bytes => 44)->writer($fh, sample_count => 1) },
    'writer byte limit'
);
error_is(
    'CW_E_ARGUMENT',
    sub { Ham::CW::Audio->new->writer(undef, sample_count => 0) },
    'writer handle validation'
);
my $writer = Ham::CW::Audio->new->writer($fh, sample_count => 0);
error_is('CW_E_ARGUMENT', sub { $writer->feed([0]) }, 'declared sample count bound');
is($writer->state, 'READY', 'count validation preserves state');
my $decoder = Ham::CW::Decoder->new(wpm => 20, max_segments => 1);
$decoder->feed({unit => 'us', segments => [{state => 'on', duration => 60000}]});
error_is(
    'CW_E_RESOURCE',
    sub { $decoder->feed({unit => 'us', segments => [{state => 'off', duration => 60000}]}) },
    'decoder segment bound'
);
is($decoder->finish->text, 'E', 'bounded decoder retains original data');
my $large = Ham::CW::Decoder->new(wpm => 20);
$large->feed({unit => 'us', segments => [{state => 'off', duration => 2**52}]});
error_is(
    'CW_E_RESOURCE',
    sub { $large->feed({unit => 'us', segments => [{state => 'on', duration => 1}]}) },
    'stream cumulative duration bound'
);
my $empty = Ham::CW::Decoder->new->finish;
ok($empty->complete, 'empty decode completes');
is($empty->text, '', 'empty decode text');
ok(@{$empty->warnings}, 'missing timing diagnostic');
my $ambiguous = Ham::CW::Decoder->new;
$ambiguous->feed(Ham::CW::Encoder->new->events('EEE'));
ok(grep($_->{code} eq 'CW_W_TIMING_AMBIGUOUS', @{$ambiguous->finish->warnings}),
    'single-length timing ambiguity');
my $invalid = Ham::CW::Decoder->new(wpm => 20);
$invalid->feed({unit => 'us', segments => [{state => 'on', duration => 110000}]});
is($invalid->finish->text, "\x{fffd}", 'invalid duration becomes replacement character');
my $outside = Ham::CW::Decoder->new;
$outside->feed({unit => 'us', segments => [{state => 'on', duration => 200}]});
is($outside->finish->text, '', 'unsupported timing range');
my $long = Ham::CW::Decoder->new;
$long->feed(Ham::CW::Encoder->new->events('CQ ' x 30));
like($long->finish->text, qr/\ACQ CQ/, 'timing fit with many observations');
my $default_error = Ham::CW::Error->new;
is($default_error->message, 'Unspecified error', 'exception default');
is_deeply($default_error->context, {}, 'default context');
my $snapshot = Ham::CW::Result->new(morse => '.-', frequency => 700, wpm => 20);
is($snapshot->morse,     '.-', 'Morse snapshot accessor');
is($snapshot->frequency, 700,  'frequency snapshot');
is($snapshot->wpm,       20,   'WPM snapshot');
error_is('CW_E_ARGUMENT', sub { Ham::CW::Result->new(typo => 1) }, 'snapshot option validation');

# A facade call with every generation option exercises its configuration contract.
my $configured = Ham::CW->new(
    wpm           => 18,
    effective_wpm => 12,
    frequency     => 650,
    sample_rate   => 8000,
    amplitude     => 0.4,
    attack_ms     => 2,
    release_ms    => 3,
    unknown       => 'error'
);
my $wav = '';
open my $output, '>', \$wav or die $!;
$configured->generate_wav('SOS', $output, max_bytes => 1000000);
close $output;
open my $input, '<', \$wav or die $!;
is(
    $configured->decode_wav(
        $input,
        frequency     => 650,
        wpm           => 18,
        effective_wpm => 12,
        stereo        => 'left',
        max_bytes     => 1000000
    )->text,
    'SOS',
    'facade configuration and reception options'
);

for my $class (
    qw(Ham::CW Ham::CW::Audio Ham::CW::Encoder Ham::CW::Decoder
    Ham::CW::Generator Ham::CW::Detector Ham::CW::MIDI Ham::CW::Result Ham::CW::Error)
    )
{
    error_is('CW_E_ARGUMENT', sub { $class->new('wpm') }, 'odd option list rejected');
}
error_is('CW_E_ARGUMENT', sub { Ham::CW->new(wpm => 20, wpm => 30) }, 'duplicate option rejected');
error_is('CW_E_ARGUMENT', sub { Ham::CW->new(undef, 20) }, 'undefined option name rejected');
error_is('CW_E_ARGUMENT', sub { Ham::CW->new([],    20) }, 'reference option name rejected');
done_testing;
