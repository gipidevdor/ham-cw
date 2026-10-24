use strict;
use warnings;
use Test::More;
use Ham::CW::Audio;
sub riff { my ($chunks) = @_; return 'RIFF' . pack('V', length($chunks) + 4) . 'WAVE' . $chunks }
my $fmt   = pack('a4VvvVVvv', 'fmt ', 16, 1, 1, 8000, 16000, 2, 16);
my $data  = pack('a4V', 'data', 2) . "\0\0";
my @cases = (
    [riff('abc'),                                   'CW_E_WAV_TRUNCATED'],
    [riff($fmt . $fmt . $data),                     'CW_E_WAV_FORMAT'],
    [riff($fmt . $data . $data),                    'CW_E_WAV_FORMAT'],
    [riff($fmt),                                    'CW_E_WAV_FORMAT'],
    [riff($data),                                   'CW_E_WAV_FORMAT'],
    [riff(pack('a4V', 'fmt ', 2) . "\0\0" . $data), 'CW_E_WAV_FORMAT'],
    [riff($fmt . $data) . 'x',                      'CW_E_WAV_FORMAT'],
    ['RIFF' . pack('V', 0) . 'WAVE',                'CW_E_WAV_FORMAT'],
);

for my $case (@cases) {
    open my $fh, '<', \$case->[0] or die $!;
    eval { Ham::CW::Audio->new->reader($fh) };
    is(ref($@) && $@->code, $case->[1], 'reject malformed chunk structure');
}
my $reordered = riff($data . $fmt);
open my $in, '<', \$reordered or die $!;
is_deeply(Ham::CW::Audio->new->read($in)->{samples}, [0], 'data before format is supported');
my $wave   = riff($fmt . $data);
my $seed   = 19;
my $errors = 0;
for (1 .. 300) {
    my $mutant = $wave;
    $seed = (1664525 * $seed + 1013904223) % 4294967296;
    my $offset = $seed % length($mutant);
    substr($mutant, $offset, 1, chr(($seed >> 16) & 255));
    open my $fh, '<', \$mutant or die $!;
    eval { Ham::CW::Audio->new(max_bytes => 4096)->read($fh) };
    if ($@) { isa_ok($@, 'Ham::CW::Error', 'mutated input has structured error'); ++$errors }
}
cmp_ok($errors, '>', 200, 'mutations exercise format rejection');
my $many = '';
open my $out, '>', \$many or die $!;
Ham::CW::Audio->new->write($out, [(0) x 5000]);
close $out;
open my $read, '<', \$many or die $!;
is(scalar @{Ham::CW::Audio->new(block_samples => 7)->read($read)->{samples}},
    5000, 'multiple output blocks and reader short final block');
done_testing;
