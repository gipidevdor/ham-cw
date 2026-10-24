package Ham::CW::_Internal::IO;
use 5.020;
use strict;
use warnings;
use Carp qw(croak);
use Exporter 'import';
use File::Basename               qw(dirname);
use File::Temp                   qw(tempfile);
use Fcntl                        qw(O_RDONLY O_WRONLY O_CREAT O_EXCL);
use Ham::CW::_Internal::Validate qw(fail);
our @EXPORT_OK = qw(read_exact write_bytes with_file);

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

sub _file_error {
    my ($path, $action, $reason) = @_;
    return Ham::CW::Error->throw(
        code    => 'CW_E_IO',
        message => "Cannot $action file '$path': $reason",
        context => {path => $path, action => $action, reason => "$reason"}
    );
}

sub with_file {
    my ($path, $mode, $action, $overwrite) = @_;
    fail('CW_E_ARGUMENT', 'File path must be a nonempty string without NUL characters')
        if !defined($path) || ref($path) || !length($path) || index($path, "\0") >= 0;
    my $writing = $mode eq 'write';
    my $flags   = $writing ? O_WRONLY | O_CREAT | O_EXCL : O_RDONLY;
    my ($handle, $temporary);
    if ($writing && $overwrite) {
        my $opened = eval {
            ($handle, $temporary) = tempfile('.ham-cw-XXXXXX', DIR => dirname($path), UNLINK => 0);
            1;
        };
        _file_error($path, 'open temporary output for', "$@") unless $opened;
    }
    else {
        sysopen $handle, $path, $flags or _file_error($path, 'open', "$!");
    }
    my $value;
    my $ok = eval {
        binmode $handle, ':raw' or _file_error($path, 'set binary mode on', "$!");
        $value = $action->($handle);
        1;
    };
    my $error       = $@;
    my $closed      = close $handle;
    my $close_error = "$!";
    if (!$ok || !$closed) {
        unlink($temporary // $path) if $writing;
        croak $error unless $ok;
        _file_error($path, 'close', $close_error);
    }
    if (defined $temporary) {
        if (!rename($temporary, $path)) {
            my $reason = "$!";
            unlink $temporary;
            _file_error($path, 'replace', $reason);
        }
    }
    return $value;
}

1;
