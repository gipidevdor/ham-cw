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
    'note=i'          => \$args{note},
    'velocity=i'      => \$args{velocity},
    'channel=i'       => \$args{channel},
    'program=i'       => \$args{program},
    'bpm=f'           => \$args{bpm},
    'ppqn=i'          => \$args{ppqn},
    'max-bytes=i'     => \$args{max_bytes},
    'unknown=s'       => \$args{unknown},
    'overwrite!'      => \$args{overwrite},
    'help'            => \$help
) or die "Invalid MIDI options; use --help\n";
if ($help) {
    print "Usage: perl examples/midi.pl [options] output.mid TEXT\n",
        "  --wpm N --effective-wpm N --note 0..127 --velocity 1..127\n",
        "  --channel 1..16 --program 0..127 --bpm N --ppqn N --max-bytes N\n",
        "  --unknown error|skip\n",
"Use --overwrite to replace an existing file. WPM controls Morse speed; BPM controls MIDI tick mapping.\n";
    exit 0;
}
my ($path, @words) = @ARGV;
die "Usage: perl examples/midi.pl [options] output.mid TEXT\n" unless defined($path) && @words;
%args = map { defined($args{$_}) ? ($_ => $args{$_}) : () } keys %args;
Ham::CW->new->write_midi(join(' ', @words), $path, %args);
