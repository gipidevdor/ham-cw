#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use lib 'lib';
use Benchmark qw(cmpthese);
use Ham::CW;
use Ham::CW::Generator;
use Ham::CW::Detector;
use Ham::CW::_Internal::PDL;
my $events  = Ham::CW->new->events('CQ CQ DE TESTCALL');
my $samples = Ham::CW::Generator->new(sample_rate => 8000)->generate($events);

for my $operation (qw(generate detect)) {
    print "$operation (8000 Hz; higher iterations/s is better)\n";
    my %cases;
    for my $backend (qw(perl pdl)) {
        $cases{$backend} = $operation eq 'generate'
            ? sub {
            Ham::CW::Generator->new(sample_rate => 8000, backend => $backend)->generate($events);
            }
            : sub {
            my $d = Ham::CW::Detector->new(sample_rate => 8000, backend => $backend);
            $d->feed($samples);
            $d->finish;
            };
    }
    cmpthese(-2, \%cases);
}

1;
