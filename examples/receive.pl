#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Carp         qw(croak);
use Getopt::Long qw(GetOptions);
use JSON::PP;
use Ham::CW;

my (%options, $json, $help);
GetOptions(
    'frequency=f'      => \$options{frequency},
    'wpm=f'            => \$options{wpm},
    'effective-wpm=f'  => \$options{effective_wpm},
    'backend=s'        => \$options{backend},
    'stereo=s'         => \$options{stereo},
    'max-frames=i'     => \$options{max_frames},
    'min-frequency=f'  => \$options{min_frequency},
    'max-frequency=f'  => \$options{max_frequency},
    'frequency-step=f' => \$options{frequency_step},
    'min-contrast=f'   => \$options{min_contrast},
    'min-purity=f'     => \$options{min_purity},
    'max-bytes=i'      => \$options{max_bytes},
    'block-samples=i'  => \$options{block_samples},
    'json!'            => \$json,
    'help'             => \$help,
) or die "Invalid receiver options; use --help\n";

if ($help) {
    print "Usage: perl examples/receive.pl [options] input.wav\n",
        "  --frequency HZ --wpm WPM --effective-wpm WPM\n",
        "  --backend perl|pdl|auto --stereo mix|left|right --max-frames N --json\n",
        "  --min-frequency HZ --max-frequency HZ --frequency-step HZ\n",
        "  --min-contrast N --min-purity N --max-bytes N --block-samples N\n";
    exit 0;
}
die "Usage: perl examples/receive.pl [options] input.wav\n" unless @ARGV == 1;
%options = map { defined($options{$_}) ? ($_ => $options{$_}) : () } keys %options;
my $result = Ham::CW->new->read_wav($ARGV[0], %options);
if ($json) {
    print JSON::PP->new->utf8->canonical->pretty->encode($result->as_hash);
}
else {
    binmode STDOUT, ':encoding(UTF-8)' or croak $!;
    print $result->text, "\n";
    for my $warning (@{$result->warnings}) {
        warn "$warning->{code}: $warning->{message}\n";
    }
}
exit($result->has_text ? 0 : 1);
