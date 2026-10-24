package Ham::CW::_Internal::Validate;
use 5.020;
use strict;
use warnings;
use Exporter 'import';
use Scalar::Util qw(looks_like_number);
use Ham::CW::Error;
our @EXPORT_OK = qw(fail number integer options samples);

sub fail {
    my ($code, $message) = @_;
    return Ham::CW::Error->throw(code => $code, message => $message);
}

sub number {
    my ($name, $value, $min, $max) = @_;
    fail('CW_E_ARGUMENT', "$name must be a finite number in [$min, $max]")
        if !defined($value)
        || ref($value)
        || !looks_like_number($value)
        || "$value" =~ /nan|inf/ix
        || $value < $min
        || $value > $max;
    return 0 + $value;
}

sub integer {
    my ($name, $value, $min, $max) = @_;
    number($name, $value, $min, $max);
    fail('CW_E_ARGUMENT', "$name must be an integer") if int($value) != $value;
    return 0 + $value;
}

sub options {
    my ($args, @names) = @_;
    my %known = map { $_ => 1 } @names;
    for my $key (keys %{$args}) {
        fail('CW_E_ARGUMENT', "Unknown option: $key") unless $known{$key};
    }
    return;
}

sub samples {
    my ($values, $limit) = @_;
    fail('CW_E_ARGUMENT', 'Samples must be an array reference') unless ref($values) eq 'ARRAY';
    fail('CW_E_RESOURCE', 'Sample block exceeds limit') if @{$values} > $limit;
    number('sample', $_, -1, 1) for @{$values};
    return;
}
1;
