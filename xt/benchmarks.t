use strict;
use warnings;
use Test::More;
use IPC::Open3 qw(open3);
use Symbol     qw(gensym);
use JSON::PP;

sub run_benchmark {
    my (@arguments) = @_;
    my $errors      = gensym();
    my $pid         = open3(undef, my $output, $errors, $^X, 'maint/benchmark.pl', @arguments);
    my $stdout      = do { local $/; <$output> };
    my $stderr      = do { local $/; <$errors> };
    close $output            or die $!;
    close $errors            or die $!;
    waitpid($pid, 0) == $pid or die $!;
    return ($?, $stdout, $stderr);
}

my @options = ('--backend', 'perl', '--operation', 'generate', '--iterations', 1);
my ($status, $output, $errors) = run_benchmark('--json', @options);
is($status, 0, 'a single timing workload succeeds') or diag($errors);
my $timing = decode_json($output);
is(scalar @{$timing->{results}}, 1,     'operation/backend selection measures exactly one case');
is($timing->{pdl_loaded},        0,     'Perl-only timing does not load the optional PDL backend');
is($timing->{sample_count},      73440, 'filtered workload retains the reference sample count');
is($timing->{results}[0]{backend},   'perl',     'selected backend is measured');
is($timing->{results}[0]{operation}, 'generate', 'selected operation is measured');
ok(!exists $timing->{results}[0]{peak_rss_bytes}, 'ordinary timings do not invent an RSS value');
cmp_ok($timing->{results}[0]{wall_seconds_per_call}, '>', 0, 'wall time per call is reported');

for my $invalid (['--backend', 'bogus'], ['--operation', 'bogus']) {
    ($status, $output, $errors) = run_benchmark(@{$invalid});
    isnt($status, 0, 'invalid workload selection fails before benchmarking');
}

SKIP: {
    skip 'RSS requires macOS/Linux and /usr/bin/time', 13
        unless ($^O eq 'darwin' || $^O eq 'linux') && -x '/usr/bin/time';
    ($status, $output, $errors) = run_benchmark('--rss', '--json', @options);
    is($status, 0, 'isolated RSS worker succeeds') or diag($errors);
    my $rss = eval { decode_json($output) };
    ok($rss, 'RSS report is valid JSON');
    if (!$rss) {
        skip 'worker did not produce a report', 11;
    }
    is($rss->{rss}{unit}, 'bytes', 'raw peak is normalized to bytes');
    like($rss->{rss}{scope}, qr/Fresh Perl process/, 'process isolation is documented');
    is(scalar @{$rss->{results}}, 1, 'RSS selection keeps one row per case');
    my $row = $rss->{results}[0];
    cmp_ok($row->{peak_rss_bytes}, '>', 0, 'native tool supplies a positive RSS peak');
    is($row->{peak_rss_mib}, $row->{peak_rss_bytes} / (1024 * 1024), 'MiB conversion is exact');
    is($row->{pdl_loaded},   0,          'Perl RSS worker does not load PDL');
    is($row->{operation},    'generate', 'RSS worker retains the selected operation');
    is($row->{iterations},   1,          'RSS worker retains the iteration count');
    cmp_ok($row->{wall_seconds_per_call}, '>', 0, 'RSS worker retains operation timing');
    ($status, $output, $errors) = run_benchmark('--rss', @options);
    is($status, 0, 'human-readable RSS report succeeds') or diag($errors);
    like($output, qr/MiB peak RSS/, 'human-readable output includes RSS units');
}
SKIP: {
    skip 'RSS requires macOS/Linux and /usr/bin/time', 5
        unless ($^O eq 'darwin' || $^O eq 'linux') && -x '/usr/bin/time';
    ($status, $output, $errors) = run_benchmark(
        '--rss',        '--json', '--backend', 'perl',
        '--iterations', 1,        '--rate',    1000,
        '--repeat',     2,        '--known-frequency'
    );
    is($status, 0, 'multiple isolated operations succeed') or diag($errors);
    my $rss = eval { decode_json($output) };
    if (!$rss) {
        skip 'worker did not produce a report', 4;
    }
    is(scalar @{$rss->{results}}, 6,    'combined report retains all six operation rows');
    is($rss->{sample_rate},       1000, 'sample rate reaches each worker');
    is($rss->{known_frequency},   1,    'known-tone selection reaches each worker');
    is($rss->{message}, 'CQ CQ DE TESTCALL CQ CQ DE TESTCALL', 'message repetitions reach workers');
}
done_testing;
