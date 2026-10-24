use 5.020;
use strict;
use warnings;
use Devel::Cover::DB;
use JSON::PP;

my ($path) = @ARGV;
die "Usage: perl maint/coverage.pl COVER_DB\n" unless defined $path;
my $db = Devel::Cover::DB->new(db => $path);
$db = $db->merge_runs;
my @files = grep { m{\Alib/Ham/|\Alib/Ham\.}x } $db->cover->items;
die "No production module coverage found\n" unless @files;
$db->calculate_summary(files => \@files, statement => 1, branch => 1, force => 1);
my $summary = $db->summary('Total');
print JSON::PP->new->canonical->pretty->encode($summary);

for my $gate ([statement => 95], [branch => 90]) {
    my ($criterion, $minimum) = @{$gate};
    my $actual = $summary->{$criterion}{percentage};
    die "Missing $criterion coverage\n" unless defined $actual;
    die "$criterion coverage $actual is below $minimum\n" if $actual < $minimum;
}
