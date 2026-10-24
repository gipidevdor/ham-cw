package Ham::CW::_Internal::Symbols;
use 5.020;
use strict;
use warnings;
use utf8;
use Exporter 'import';
our @EXPORT_OK = qw(alphabet reverse_alphabet prosigns);

sub alphabet {
    return {
        A    => '.-',
        B    => '-...',
        C    => '-.-.',
        D    => '-..',
        E    => '.',
        F    => '..-.',
        G    => '--.',
        H    => '....',
        I    => '..',
        J    => '.---',
        K    => '-.-',
        L    => '.-..',
        M    => '--',
        N    => '-.',
        O    => '---',
        P    => '.--.',
        Q    => '--.-',
        R    => '.-.',
        S    => '...',
        T    => '-',
        U    => '..-',
        V    => '...-',
        W    => '.--',
        X    => '-..-',
        Y    => '-.--',
        Z    => '--..',
        'É'  => '..-..',
        0    => '-----',
        1    => '.----',
        2    => '..---',
        3    => '...--',
        4    => '....-',
        5    => '.....',
        6    => '-....',
        7    => '--...',
        8    => '---..',
        9    => '----.',
        '.'  => '.-.-.-',
        ','  => '--..--',
        ':'  => '---...',
        '?'  => '..--..',
        q{'} => '.----.',
        '-'  => '-....-',
        '/'  => '-..-.',
        '('  => '-.--.',
        ')'  => '-.--.-',
        q{"} => '.-..-.',
        '='  => '-...-',
        '+'  => '.-.-.',
        '@'  => '.--.-.',
    };
}

sub prosigns {
    return {
        AR  => '.-.-.',
        AS  => '.-...',
        CT  => '-.-.-',
        SK  => '...-.-',
        HH  => '........',
        SN  => '...-.',
        SOS => '...---...'
    };
}

sub reverse_alphabet {
    my $a = alphabet();
    my %r = reverse %{$a};
    my $p = prosigns();

    # Shared waveforms retain punctuation unless the caller requests prosigns.
    for my $name (sort keys %{$p}) { $r{$p->{$name}} //= "<$name>" }
    return \%r;
}
1;
