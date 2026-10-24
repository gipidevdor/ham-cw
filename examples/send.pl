#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Ham::CW;

my ($path, @words) = @ARGV;
die "Usage: perl examples/send.pl output.wav TEXT\n" unless defined($path) && @words;
open my $output, '>:raw', $path or die "Cannot open $path: $!\n";
Ham::CW->new(wpm => 20)->generate_wav(join(' ', @words), $output);
close $output or die "Cannot close $path: $!\n";
