use strict;
use warnings;
use utf8;
use Test::More;
use Ham::CW;
my $cw = Ham::CW->new;

# Independent reference vectors, not the implementation's symbol table.
my @letters =
    qw(.- -... -.-. -.. . ..-. --. .... .. .--- -.- .-.. -- -. --- .--. --.- .-. ... - ..- ...- .-- -..- -.-- --..);
my @digits = qw(----- .---- ..--- ...-- ....- ..... -.... --... ---.. ----.);
for my $i (0 .. 25) {
    my $letter = chr(65 + $i);
    is($cw->encode(lc $letter),   $letters[$i], "encode $letter");
    is($cw->decode($letters[$i]), $letter,      "decode $letter");
}
for my $i (0 .. 9) {
    is($cw->encode("$i"),        $digits[$i], "encode $i");
    is($cw->decode($digits[$i]), "$i",        "decode $i");
}
my @punct = (
    ['.',  '.-.-.-'],
    [',',  '--..--'],
    [':',  '---...'],
    ['?',  '..--..'],
    [q{'}, '.----.'],
    ['-',  '-....-'],
    ['/',  '-..-.'],
    ['(',  '-.--.'],
    [')',  '-.--.-'],
    [q{"}, '.-..-.'],
    ['=',  '-...-'],
    ['+',  '.-.-.'],
    ['@',  '.--.-.'],
    ['É',  '..-..']
);
for my $pair (@punct) {
    is($cw->encode($pair->[0]), $pair->[1], 'encode punctuation');
    is($cw->decode($pair->[1]), $pair->[0], 'decode punctuation');
}
is(
    $cw->encode("  cq\tde\nTESTCALL  "),
    '-.-. --.- / -.. . / - . ... - -.-. .- .-.. .-..',
    'normalize whitespace'
);
is($cw->encode('AR'),    '.- .-.', 'letters stay separate');
is($cw->encode('<AR>'),  '.-.-.',  'explicit AR');
is($cw->decode('.-.-.'), '+',      'punctuation preferred');
is(Ham::CW::Decoder->new(prefer_prosigns => 1)->decode('.-.-.'),
    '<AR>', 'explicit ambiguity policy');
my %prosigns = (
    AR  => '.-.-.',
    AS  => '.-...',
    CT  => '-.-.-',
    SK  => '...-.-',
    HH  => '........',
    SN  => '...-.',
    SOS => '...---...'
);
for my $name (sort keys %prosigns) { is($cw->encode("<$name>"), $prosigns{$name}, "prosign $name") }
is($cw->encode(''),                                          '',          'empty text');
is($cw->decode('  '),                                        '',          'empty Morse');
is(Ham::CW::Encoder->new(unknown => 'skip')->encode('A! B'), '.- / -...', 'explicit skip policy');

for my $bad ('!', 'ß', '<NOPE>', '<AR', "e\x{301}") {
    eval { $cw->encode($bad) };
    isa_ok($@, 'Ham::CW::Error');
    is((ref($@) ? $@->code : "$@"), 'CW_E_SYMBOL', 'strict unknown');
}
for my $bad ('/ ...', '... /', '... // ---', '... x', '------') {
    eval { $cw->decode($bad) };
    is(ref($@) && (ref($@) ? $@->code : "$@"), 'CW_E_SYMBOL', 'reject malformed Morse');
}
for my $text ('HELLO WORLD', 'CQ CQ DE TESTCALL', '0123456789', 'TEST (A/B)?') {
    is($cw->decode($cw->encode($text)), $text, 'text round trip');
}
done_testing;
