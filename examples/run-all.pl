#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Carp qw(croak);
use File::Spec;
use FindBin;
use Getopt::Long qw(GetOptions);
use JSON::PP;

my ($backend, $only, $list) = ('perl', undef, 0);
GetOptions('backend=s' => \$backend, 'only=s' => \$only, 'list' => \$list)
    or croak
    'Usage: perl -Ilib examples/run-all.pl [--backend perl|auto|pdl] [--only NAME] [--list]';
croak 'Unexpected arguments' if @ARGV;
croak 'Unknown backend' unless $backend =~ /\A(?:perl|auto|pdl)\z/x;
open my $input, '<:raw', File::Spec->catfile($FindBin::Bin, 'routes.json') or croak $!;
my $bytes = do { local $/ = undef; <$input> };
close $input or croak $!;
my $routes   = decode_json($bytes);
my @includes = map { '-I' . File::Spec->rel2abs($_) } grep { !ref $_ } @INC;
my $selected = 0;

for my $route (@{$routes}) {
    (my $name = $route->{file}) =~ s/\.pl\z//x;
    next if defined($only) && $only ne $name;
    ++$selected;
    if ($list) { print "$name: $route->{description}\n"; next }
    print "Running $name", $route->{backend} ? " ($backend)" : '', "\n";
    my @arguments = $route->{backend} ? ($backend) : ();
    system $^X, @includes, File::Spec->catfile($FindBin::Bin, $route->{file}), @arguments;
    croak "Example failed: $name" if $?;
}
croak 'No matching example'                unless $selected;
print "All selected examples completed.\n" unless $list;
