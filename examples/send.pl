#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Ham::CW;
my (%args, $help);
GetOptions(
    'wpm=f'           => \$args{wpm},
    'effective-wpm=f' => \$args{effective_wpm},
    'frequency=f'     => \$args{frequency},
    'sample-rate=i'   => \$args{sample_rate},
    'amplitude=f'     => \$args{amplitude},
    'attack-ms=f'     => \$args{attack_ms},
    'release-ms=f'    => \$args{release_ms},
    'backend=s'       => \$args{backend},
    'bits=i'          => \$args{bits},
    'max-bytes=i'     => \$args{max_bytes},
    'max-samples=i'   => \$args{max_samples},
    'block-size=i'    => \$args{block_size},
    'unknown=s'       => \$args{unknown},
    'overwrite!'      => \$args{overwrite},
    'help'            => \$help
) or die "Invalid sender options; use --help\n";
if ($help) {
    print "Usage: perl examples/send.pl [options] output.wav TEXT\n",
        "  --wpm N --effective-wpm N --frequency HZ --sample-rate HZ --bits 8|16|24\n",
        "  --amplitude 0..1 --attack-ms N --release-ms N --backend perl|pdl|auto\n",
        "  --max-bytes N --max-samples N --block-size N --unknown error|skip\n",
"Use --overwrite to replace an existing file. Quote text containing prosigns, e.g. 'CQ <AR>'.\n";
    exit 0;
}
my ($path, @words) = @ARGV;
die "Usage: perl examples/send.pl [options] output.wav TEXT\n" unless defined($path) && @words;
%args = map { defined($args{$_}) ? ($_ => $args{$_}) : () } keys %args;
Ham::CW->new->write_wav(join(' ', @words), $path, %args);
