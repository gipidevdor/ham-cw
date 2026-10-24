use strict;
use warnings;
use Test::More;
for my $module (
    qw(Ham::CW Ham::CW::Encoder Ham::CW::Decoder Ham::CW::Events
    Ham::CW::Generator Ham::CW::Detector Ham::CW::MIDI Ham::CW::Audio Ham::CW::Result Ham::CW::Error)
    )
{
    use_ok($module);
}
done_testing;
