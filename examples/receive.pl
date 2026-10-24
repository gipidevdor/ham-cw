#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Carp         qw(croak);
use Getopt::Long qw(GetOptions);
use JSON::PP;
use Ham::CW;

my (%options, $json, $help, $all);
GetOptions(
    'frequency=f'        => \$options{frequency},
    'wpm=f'              => \$options{wpm},
    'effective-wpm=f'    => \$options{effective_wpm},
    'backend=s'          => \$options{backend},
    'stereo=s'           => \$options{stereo},
    'max-frames=i'       => \$options{max_frames},
    'min-frequency=f'    => \$options{min_frequency},
    'max-frequency=f'    => \$options{max_frequency},
    'frequency-step=f'   => \$options{frequency_step},
    'min-contrast=f'     => \$options{min_contrast},
    'filter-bandwidth=f' => \$options{filter_bandwidth},
    'min-snr-db=f'       => \$options{min_snr_db},
    'all-stations'       => \$all,
    'min-purity=f'       => \$options{min_purity},
    'max-bytes=i'        => \$options{max_bytes},
    'block-samples=i'    => \$options{block_samples},
    'json!'              => \$json,
    'help'               => \$help,
) or die "Invalid receiver options; use --help\n";

if ($help) {
    print "Usage: perl examples/receive.pl [options] input.wav\n",
        "  --frequency HZ --wpm WPM --effective-wpm WPM\n",
        "  --backend perl|pdl|auto --stereo mix|left|right --max-frames N --json\n",
        "  --min-frequency HZ --max-frequency HZ --frequency-step HZ\n",
        "  --filter-bandwidth HZ --min-snr-db DB --all-stations\n",
        "  --min-contrast N --min-purity N --max-bytes N --block-samples N\n";
    exit 0;
}
die "Usage: perl examples/receive.pl [options] input.wav\n" unless @ARGV == 1;
%options = map { defined($options{$_}) ? ($_ => $options{$_}) : () } keys %options;
my $method  = $all ? 'read_wav_channels' : 'read_wav';
my $result  = Ham::CW->new->$method($ARGV[0], %options);
my @results = $all ? @{$result} : ($result);
if ($json) {
    print JSON::PP->new->utf8->canonical->pretty->encode(
        $all ? [map { $_->as_hash } @results] : $result->as_hash);
}
else {
    binmode STDOUT, ':encoding(UTF-8)' or croak $!;
    for my $station (@results) {
        print($all ? $station->frequency . " Hz: " : '', $station->text, "\n");
        for my $warning (@{$station->warnings}) {
            warn "$warning->{code}: $warning->{message}\n";
        }
    }
}
exit((grep { $_->has_text } @results) ? 0 : 1);
