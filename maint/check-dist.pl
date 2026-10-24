#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Module::CPANTS::Analyse;
use JSON::PP;

my ($path) = @ARGV;
die "Usage: perl maint/check-dist.pl DISTRIBUTION.tar.gz\n" unless defined($path) && -f $path;
my $analysis = Module::CPANTS::Analyse->new({dist => $path});
my $result   = $analysis->run;
my @failed   = sort grep { !$result->{kwalitee}{$_} } keys %{$result->{kwalitee}};
my $report   = {checks => $result->{kwalitee}, diagnostics => $result->{error} // {}};
print JSON::PP->new->canonical->pretty->encode($report);
die "Failed archive indicators: @failed\n" if @failed;
die "Archive diagnostics require review\n" if keys %{$report->{diagnostics}};
