package Ham::CW::_Internal::Backend;
use 5.020;
use strict;
use warnings;
use Ham::CW::_Internal::Validate qw(fail);

sub resolve {
    my ($backend) = @_;
    $backend //= 'perl';
    fail('CW_E_ARGUMENT', 'backend must be perl, pdl or auto')
        if ref($backend) || $backend !~ /\A(?:perl|pdl|auto)\z/x;
    return 'perl' if $backend eq 'perl';
    my $available = eval { require Ham::CW::_Internal::PDL; 1 };
    return 'pdl'  if $available;
    return 'perl' if $backend eq 'auto';
    fail('CW_E_ARGUMENT', 'PDL backend unavailable; install PDL 2.081 or later');
    return;
}
1;
