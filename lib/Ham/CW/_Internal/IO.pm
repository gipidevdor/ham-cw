package Ham::CW::_Internal::IO;
use 5.020;
use strict;
use warnings;
use Exporter 'import';
use Ham::CW::_Internal::Validate qw(fail);
our @EXPORT_OK = qw(read_exact write_bytes);

sub read_exact {
    my ($fh, $count) = @_;
    my $out = '';
    while (length($out) < $count) {
        my $n = read($fh, my $part, $count - length($out));
        fail('CW_E_IO',            'Cannot read WAV handle') unless defined $n;
        fail('CW_E_WAV_TRUNCATED', 'Unexpected end of WAV')  unless $n;
        $out .= $part;
    }
    return $out;
}

sub write_bytes {
    my ($fh, $bytes) = @_;
    print {$fh} $bytes or fail('CW_E_IO', 'Cannot write WAV handle');
    return;
}
1;
