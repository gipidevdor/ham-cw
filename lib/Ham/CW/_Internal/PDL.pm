package Ham::CW::_Internal::PDL;
use 5.020;
use strict;
use warnings;
use PDL 2.081 ();
use PDL::LiteF;
my $PI = 4 * atan2(1, 1);

sub tone {
    my ($self, $segment, $offset, $absolute, $count) = @_;
    return [(0) x $count] if $segment->{state} eq 'off';
    my $index    = PDL->sequence(PDL::double(), $count);
    my $position = $index + $offset;
    my $cycles   = ($index + $absolute) * $self->{frequency} / $self->{sample_rate};
    my $values   = (2 * $PI * ($cycles - $cycles->floor))->sin * $self->{amplitude};
    for my $ramp (['attack_ms', $position], ['release_ms', $segment->{samples} - 1 - $position]) {
        my $length = $self->{$ramp->[0]} * $self->{sample_rate} / 1000;
        $length = $segment->{samples} / 2 if $length > $segment->{samples} / 2;
        next unless $length;
        my $distance = $ramp->[1]->clip(0, $length);
        $values *= 0.5 * (1 - ($PI * $distance / $length)->cos);
    }
    return [$values->list];
}

sub frames {
    my ($self, $blocks) = @_;
    my $n        = @{$blocks->[0]};
    my $data     = PDL->pdl(PDL::double(), $blocks);
    my $window   = PDL->pdl(PDL::double(), [@{$self->{window}}[0 .. $n - 1]]);
    my $windowed = ($data - ($data->sumover / $n)->dummy(0)) * $window;
    my $energy   = ($windowed * $windowed)->sumover;
    my $kernels  = $self->{pdl_kernels}{$n};
    if (!$kernels) {
        my $index = PDL->sequence(PDL::double(), $n);
        $kernels = [];
        for my $frequency (@{$self->{frequencies}}) {
            my $phase = $index * (2 * $PI * $frequency / $self->{sample_rate});
            push @{$kernels}, [$phase->cos, $phase->sin];
        }
        $self->{pdl_kernels}{$n} = $kernels;
    }
    my @powers;
    for my $kernel (@{$kernels}) {
        my $real = ($windowed * $kernel->[0])->sumover;
        my $imag = ($windowed * $kernel->[1])->sumover;
        push @powers, $real * $real + $imag * $imag;
    }
    my @rows = map { [] } @{$blocks};
    for my $power (@powers) {
        my @values = $power->list;
        push @{$rows[$_]}, $values[$_] for 0 .. $#rows;
    }
    my @energy = $energy->list;
    push @{$self->{frames}},
        map { +{powers => $rows[$_], energy => $energy[$_], samples => $n} } 0 .. $#rows;
    return;
}

sub decode_pcm {
    my ($raw, $bits, $channels, $policy) = @_;
    my @integers;
    if    ($bits == 8)  { @integers = unpack('C*',  $raw) }
    elsif ($bits == 16) { @integers = unpack('s<*', $raw) }
    else {
        for (my $i = 0; $i < length $raw; $i += 3) {
            push @integers, unpack('V', substr($raw, $i, 3) . "\0");
        }
    }
    return [] unless @integers;
    my $values = PDL->pdl(PDL::double(), \@integers);
    if    ($bits == 8)  { $values -= 128 }
    elsif ($bits == 24) { $values -= ($values >= 8388608) * 16777216 }
    $values /= 2**($bits - 1);
    if ($channels == 2) {
        $values = $values->reshape(2, scalar(@integers) / 2);
        $values =
              $policy eq 'mix'
            ? $values->sumover / 2
            : $values->slice(($policy eq 'left' ? '0' : '1') . ',:')->flat;
    }
    return [$values->list];
}

sub quantize {
    my ($values, $scale) = @_;
    return () unless @{$values};
    my $scaled  = PDL->pdl(PDL::double(), $values) * $scale;
    my $rounded = ($scaled->abs + 0.5)->floor * (($scaled >= 0) * 2 - 1);
    return $rounded->clip(-$scale, $scale - 1)->list;
}
1;
