use strict;
use warnings;
use Test::More;
use Test::Kwalitee qw(kwalitee_ok);
use Ham::CW        ();
if (!-f 'META.yml') {
    chdir "Ham-CW-$Ham::CW::VERSION" or die "Run make distmeta before author checks: $!";
}
kwalitee_ok();
done_testing;
