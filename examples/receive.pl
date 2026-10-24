use 5.020;
use strict;
use warnings;
use Ham::CW;

my ($path) = @ARGV;
die "Usage: perl examples/receive.pl input.wav\n" unless defined $path;
open my $input, '<:raw', $path or die "Cannot open $path: $!\n";
my $result = Ham::CW->new->decode_wav($input);
close $input or die "Cannot close $path: $!\n";
print $result->text, "\n";
for my $warning (@{$result->warnings}) {
    warn "$warning->{code}: $warning->{message}\n";
}
exit(length($result->text) ? 0 : 1);
