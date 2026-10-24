use strict;
use warnings;
use Test::More;
use Ham::CW;
use lib 't/lib';
use Reference qw(reference_sos noise);

for my $rate (1000, 1200) {
    ok(Ham::CW->new(sample_rate => $rate), "usable defaults at $rate Hz");
}
my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    open my $fh, '>', \my $bytes or die $!;
    eval { Ham::CW::Audio->new->writer($fh, bits => 'abc', sample_count => 0) };
    is(ref($@) ? $@->code : "$@", 'CW_E_ARGUMENT', 'invalid bits structured error');
}
is_deeply(\@warnings, [], 'no raw numeric warning');
is_deeply(Ham::CW::Result->new->events, {unit => 'us', segments => []}, 'canonical empty events');
for my $token (qw(BT KN BK KA VE)) {
    ok(length Ham::CW->new->encode("<$token>"), "$token supported");
}
for my $space ("\x{a0}", "\x{2003}") {
    eval { Ham::CW->new->encode("A${space}B") };
    is(ref($@) ? $@->code : "$@", 'CW_E_SYMBOL', 'Unicode separators follow symbol policy');
}
eval { Ham::CW::Detector->new(wpm => 61) };
is(ref($@) ? $@->code : "$@", 'CW_E_ARGUMENT', 'receive speed limit explicit');
for my $level (0.01, 0.02, 0.08) {
    my $samples = noise(8000 * 62, $level);
    my $signal = reference_sos();
    $samples->[8000 * 30 + $_] += $signal->[$_] for 0 .. $#{$signal};
    my $detector = Ham::CW::Detector->new(sample_rate => 8000, frequency => 650, wpm => 20);
    for (my $i = 0; $i < @{$samples}; $i += 4096) {
        my $end = $i + 4095;
        $end = $#{$samples} if $end > $#{$samples};
        $detector->feed([@{$samples}[$i .. $end]]);
    }
    is($detector->finish->text, 'SOS', "sparse message surrounded by noise $level");
}
my $cw = Ham::CW->new(sample_rate => 8000, frequency => 650, wpm => 20, effective_wpm => 10);
my $bytes = '';
open my $out, '>:raw', \$bytes or die $!;
$cw->generate_wav('CQ TEST', $out);
close $out or die $!;
open my $in, '<:raw', \$bytes or die $!;
is($cw->decode_wav($in, frequency => 650, wpm => 20, effective_wpm => 10)->text,
    'CQ TEST', 'Farnsworth audio with spacing hint');
seek($in, 0, 0) or die $!;
my $r = $cw->decode_wav($in, frequency => 650, wpm => 20);
ok(grep($_->{code} eq 'CW_W_SPACING_AMBIGUOUS', @{$r->warnings}), 'missing spacing hint warns');
my $d = Ham::CW::Decoder->new(effective_wpm => 60);
$d->feed($cw->events('SOS'));
eval { $d->finish };
is(ref($@) ? $@->code : "$@", 'CW_E_ARGUMENT', 'effective speed checked against estimated speed');
my $events = Ham::CW->new->events('CQ TEST CQ TEST CQ TEST');
$events->{segments}[0]{duration} *= 2;
my $audio = Ham::CW::Generator->new(sample_rate => 8000, frequency => 650)->generate($events);
my $detector = Ham::CW::Detector->new(sample_rate => 8000, frequency => 650, wpm => 20);
$detector->feed($audio);
like($detector->finish->text, qr/TEST CQ TEST/, 'one malformed mark preserves subsequent text');
# A recording exceeding the default 120 s remains accessible through the facade.
my $long = '';
open my $long_out, '>:raw', \$long or die $!;
my $writer = Ham::CW::Audio->new->writer($long_out, sample_rate => 1000, sample_count => 125000);
$writer->feed([(0) x 1000]) for 1 .. 125;
$writer->finish;
close $long_out or die $!;
open my $long_in, '<:raw', \$long or die $!;
ok(Ham::CW->new->decode_wav($long_in, max_frames => 26000)->complete, 'facade exposes history limit');
done_testing;
