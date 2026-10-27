#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use lib 'lib';
use Carp qw(croak);
use Config;
use File::Temp   qw(tempfile);
use Getopt::Long qw(GetOptions);
use IPC::Open3   qw(open3);
use JSON::PP;
use Symbol      qw(gensym);
use Time::HiRes qw(time);
use Ham::CW;
use Ham::CW::Generator;
use Ham::CW::Detector;
use Ham::CW::_Internal::Validate qw(integer);

my ($rate,  $block_size, $repeat, $iterations, $snapshots) = (8000, 4096, 1, 3, 100);
my ($known, $json,       $help,   $rss,        $operation);
my $backend_selection = 'all';
my @operations        = qw(detect generate snapshot_rebuild snapshots wav_decode wav_generate);
GetOptions(
    'rate=i'           => \$rate,
    'block=i'          => \$block_size,
    'repeat=i'         => \$repeat,
    'iterations=i'     => \$iterations,
    'snapshots=i'      => \$snapshots,
    'known-frequency!' => \$known,
    'json!'            => \$json,
    'rss!'             => \$rss,
    'backend=s'        => \$backend_selection,
    'operation=s'      => \$operation,
    'help'             => \$help
) or die "Invalid benchmark options\n";

if ($help) {
    print "Usage: perl maint/benchmark.pl [--rate 8000] [--block 4096] [--repeat 1]\n",
        "  [--iterations 3] [--snapshots 100] [--known-frequency] [--json] [--rss]\n",
        "  [--backend all|perl|pdl] [--operation ", join('|', @operations), "]\n",
        "RSS: fresh process per operation/backend; macOS or Linux /usr/bin/time required.\n";
    exit 0;
}
die "Unexpected arguments\n" if @ARGV;
integer('rate',       $rate,       1000, 384000);
integer('block',      $block_size, 1,    1000000);
integer('repeat',     $repeat,     1,    100);
integer('iterations', $iterations, 1,    10000);
integer('snapshots',  $snapshots,  1,    1000000);
croak 'backend must be all, perl or pdl' unless $backend_selection =~ /\A(?:all|perl|pdl)\z/x;
croak 'Unknown benchmark operation'
    if defined($operation) && !grep { $_ eq $operation } @operations;
my @selected_operations = defined($operation)         ? ($operation) : @operations;
my @backends            = $backend_selection eq 'all' ? ('perl')     : ($backend_selection);

# A Perl-only worker must not load PDL while checking whether it is installed.
my $pdl_available;
if ($backend_selection ne 'perl') {
    $pdl_available = eval { require Ham::CW::_Internal::PDL; 1 } ? 1 : 0;
    croak 'PDL backend is unavailable' if $backend_selection eq 'pdl' && !$pdl_available;
    push @backends, 'pdl' if $backend_selection eq 'all' && $pdl_available;
}
if ($rss) {
    print_report(measure_rss(), $json);
    exit 0;
}
print_report(measure_timing(), $json);

sub prepare_input {
    my $frequency    = $rate > 1300 ? 650 : $rate / 4;
    my $cw           = Ham::CW->new(sample_rate => $rate, frequency => $frequency);
    my $text         = join ' ', ('CQ CQ DE TESTCALL') x $repeat;
    my $events       = $cw->events($text);
    my $sampled      = $cw->sampled_events($text);
    my $sample_count = 0;
    $sample_count += $_->{samples} for @{$sampled->{segments}};
    my $samples;

    if (!defined($operation) || $operation =~ /\A(?:detect|snapshots|snapshot_rebuild)\z/x) {
        $samples =
            Ham::CW::Generator->new(sample_rate => $rate, frequency => $frequency)
            ->generate($events);
    }
    my $wav = '';
    if (!defined($operation) || $operation eq 'wav_decode') {
        open my $out, '>:raw', \$wav or croak $!;
        $cw->generate_wav($text, $out);
        close $out or croak $!;
    }
    return ($frequency, $text, $events, $samples, $wav, $sample_count);
}

sub measure_timing {
    my ($frequency, $text, $events, $samples, $wav, $sample_count) = prepare_input();
    my @results;

    for my $backend (@backends) {
        my %detector_options = (sample_rate => $rate, backend => $backend);
        $detector_options{frequency} = $frequency if $known;
        my $feed = sub { feed_blocks($_[0], $samples, $block_size); };
        my $ready;
        if (!defined($operation) || $operation =~ /\A(?:snapshots|snapshot_rebuild)\z/x) {
            $ready = Ham::CW::Detector->new(%detector_options);
            $feed->($ready);
            $ready->result;
        }
        my %cases = (
            generate => sub {
                Ham::CW::Generator->new(
                    sample_rate => $rate,
                    frequency   => $frequency,
                    backend     => $backend
                )->generate($events);
            },
            detect => sub {
                my $detector = Ham::CW::Detector->new(%detector_options);
                $feed->($detector);
                $detector->finish;
            },
            wav_generate => sub {
                open my $handle, '>:raw', \my $bytes or croak $!;
                Ham::CW->new(sample_rate => $rate, frequency => $frequency, backend => $backend)
                    ->generate_wav($text, $handle);
                close $handle or croak $!;
            },
            wav_decode => sub {
                open my $handle, '<:raw', \$wav or croak $!;
                Ham::CW->new(backend => $backend)
                    ->decode_wav($handle, $known ? (frequency => $frequency) : ());
                close $handle or croak $!;
            },
            snapshot_rebuild => sub { $ready->_analyze(0); },
            snapshots        => sub { $ready->result for 1 .. $snapshots; },
        );
        for my $operation (@selected_operations) {
            my ($user_before, $system_before) = times;
            my $start = time;
            $cases{$operation}->() for 1 .. $iterations;
            my $elapsed = time - $start;
            my ($user_after, $system_after) = times;
            my $cpu = $user_after + $system_after - $user_before - $system_before;
            push @results,
                {
                backend               => $backend,
                operation             => $operation,
                iterations            => $iterations,
                cpu_seconds           => $cpu,
                wall_seconds          => $elapsed,
                wall_seconds_per_call => $elapsed / $iterations,
                cpu_seconds_per_call  => $cpu / $iterations,
                };
        }
    }
    my $report = {
        perl               => "$^V",
        platform           => $^O,
        architecture       => $Config{archname},
        pdl_available      => $pdl_available,
        pdl_loaded         => exists($INC{'Ham/CW/_Internal/PDL.pm'}) ? 1               : 0,
        pdl_version        => exists($INC{'Ham/CW/_Internal/PDL.pm'}) ? "$PDL::VERSION" : undef,
        backend_selection  => $backend_selection,
        message            => $text,
        frequency          => $frequency,
        sample_rate        => $rate,
        block_samples      => $block_size,
        sample_count       => $sample_count,
        audio_seconds      => $sample_count / $rate,
        known_frequency    => $known ? 1 : 0,
        snapshots_per_call => $snapshots,
        results            => \@results,
    };
    return $report;
}

sub measure_rss {
    croak 'RSS measurement requires macOS or Linux with /usr/bin/time'
        unless ($^O eq 'darwin' || $^O eq 'linux') && -x '/usr/bin/time';
    my ($combined, @rows);
    for my $backend (@backends) {
        for my $name (@selected_operations) {
            my ($usage, $usage_path) = tempfile(UNLINK => 1);
            my ($output) = tempfile(UNLINK => 1);
            my @command = (
                '/usr/bin/time', $^O eq 'darwin' ? '-l' : '-v',
                '-o',            $usage_path,
                $^X,             $0,
                '--json',        '--backend',
                $backend,        '--operation',
                $name,           '--rate',
                $rate,           '--block',
                $block_size,     '--repeat',
                $repeat,         '--iterations',
                $iterations,     '--snapshots',
                $snapshots,      $known ? '--known-frequency' : '--no-known-frequency'
            );
            local $ENV{LC_ALL} = 'C';
            my $errors     = gensym();
            my $pid        = open3(undef, '>&' . fileno($output), $errors, @command);
            my $error_text = do { local $/ = undef; <$errors> }
                // '';
            close $errors            or croak $!;
            waitpid($pid, 0) == $pid or croak "Cannot wait for RSS worker: $!";
            my $status = $?;
            seek($usage, 0, 0) or croak $!;
            my $usage_text = do { local $/ = undef; <$usage> }
                // '';
            croak "RSS worker $backend/$name failed ($status): $error_text $usage_text"
                if $status;
            my $darwin_label = qr/maximum\s+resident\s+set\s+size/x;
            my $linux_label  = qr/Maximum\s+resident\s+set\s+size/x;
            my ($peak) =
                  $^O eq 'darwin'
                ? $usage_text =~ /^\s*(\d+)\s+$darwin_label\s*$/mx
                : $usage_text =~ /^\s*$linux_label\s+\(kbytes\):\s*(\d+)\s*$/mx;
            croak "RSS worker $backend/$name did not report a positive peak" unless $peak;
            $peak *= 1024 if $^O eq 'linux';
            seek($output, 0, 0) or croak $!;
            my $data = JSON::PP->new->decode(do { local $/ = undef; <$output> });
            $combined //= $data;
            my $row = $data->{results}[0];
            $row->{peak_rss_bytes} = 0 + $peak;
            $row->{peak_rss_mib}   = $peak / (1024 * 1024);
            $row->{pdl_loaded}     = $data->{pdl_loaded};
            push @rows, $row;
            close $usage  or croak $!;
            close $output or croak $!;
        }
    }
    $combined->{results}           = \@rows;
    $combined->{backend_selection} = $backend_selection;
    $combined->{pdl_available}     = $pdl_available;
    delete $combined->{pdl_loaded};
    $combined->{pdl_version} = $pdl_available ? "$PDL::VERSION" : undef;
    $combined->{rss}         = {
        metric => 'peak resident set size',
        unit   => 'bytes',
        method => $^O eq 'darwin'
        ? '/usr/bin/time -l; ru_maxrss in bytes'
        : '/usr/bin/time -v; ru_maxrss in KiB, multiplied by 1024',
        scope =>
'Fresh Perl process per operation/backend; includes startup, modules, input preparation and all iterations; not an allocation delta or per-call average',
        timing_scope =>
            'Only operation calls; excludes process startup, module loading and input preparation',
    };
    return $combined;
}

sub print_report {
    my ($data, $as_json) = @_;
    if ($as_json) { print JSON::PP->new->canonical->pretty->encode($data); }
    else {
        printf "Perl %s; %d Hz; %.2f seconds audio; %d sample blocks; %s tone\n",
            $data->{perl}, $data->{sample_rate}, $data->{audio_seconds},
            $data->{block_samples}, $data->{known_frequency} ? 'known' : 'searched';
        print "Measuring Perl only\n" if $data->{backend_selection} eq 'perl';
        print "PDL unavailable: measuring Perl only\n"
            if $data->{backend_selection} eq 'all' && !$data->{pdl_available};
        for my $row (@{$data->{results}}) {
            printf "%-5s %-17s %.6f CPU s/call; %.6f wall s/call (%d iterations)",
                @{$row}
                {qw(backend operation cpu_seconds_per_call wall_seconds_per_call iterations)};
            printf "; %.2f MiB peak RSS", $row->{peak_rss_mib} if exists $row->{peak_rss_mib};
            print "\n";
        }
        print "$data->{rss}{scope}\n" if $data->{rss};
        print "Snapshot calls contain $data->{snapshots_per_call} cached reads; ",
            "very short timings may round to zero.\n";
    }
    return;
}

sub feed_blocks {
    my ($detector, $input_samples, $size) = @_;
    for (my $offset = 0; $offset < @{$input_samples}; $offset += $size) {
        my $end = $offset + $size - 1;
        $end = $#{$input_samples} if $end > $#{$input_samples};
        $detector->feed([@{$input_samples}[$offset .. $end]]);
    }
    return;
}

1;
