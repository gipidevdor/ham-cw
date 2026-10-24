package Ham::CW::Events;
use 5.020;
use strict;
use warnings;
use Exporter 'import';
use Ham::CW::_Internal::Validate qw(fail integer);
our $VERSION   = '0.001';
our @EXPORT_OK = qw(validate_events to_samples to_timed);
my $MAX = 2**52;

sub validate_events {
    my ($events) = @_;
    fail('CW_E_ARGUMENT', 'Events must contain a segments array')
        unless ref($events) eq 'HASH' && ref($events->{segments}) eq 'ARRAY';
    my $timed = exists $events->{unit};
    fail('CW_E_ARGUMENT', 'Use either unit or sample_rate')
        if $timed && exists $events->{sample_rate};
    if ($timed) {
        fail('CW_E_ARGUMENT', 'TimedEvents unit must be us') unless $events->{unit} eq 'us';
    }
    else { integer('sample_rate', $events->{sample_rate}, 1000, 384000) }
    my $field = $timed ? 'duration' : 'samples';
    my ($previous_state, $total) = ('', 0);
    for my $s (@{$events->{segments}}) {
        fail('CW_E_ARGUMENT', 'Invalid segment')
            unless ref($s) eq 'HASH'
            && defined($s->{state})
            && $s->{state} =~ /\A(?:on|off)\z/x;
        fail('CW_E_TIMING', 'Segment states must alternate') if $s->{state} eq $previous_state;
        integer($field, $s->{$field}, 1, $MAX);
        $total += $s->{$field};
        fail('CW_E_RESOURCE', 'Event duration exceeds exact integer range') if $total > $MAX;
        $previous_state = $s->{state};
    }
    return $field;
}

sub _convert {
    my ($events, $ratio, $field, $header) = @_;
    my ($total, $previous) = (0, 0);
    my @out;
    my $input = validate_events($events);
    for my $s (@{$events->{segments}}) {
        $total += $s->{$input};
        fail('CW_E_RESOURCE', 'Converted duration exceeds exact integer range')
            if $total * $ratio > $MAX;
        my $end = int($total * $ratio + 0.5);
        fail('CW_E_TIMING', 'Resolution would produce a zero-length segment') if $end <= $previous;
        push @out, {state => $s->{state}, $field => $end - $previous};
        $previous = $end;
    }
    return {%{$header}, segments => \@out};
}

sub to_samples {
    my ($events, $rate) = @_;
    integer('sample_rate', $rate, 1000, 384000);
    fail('CW_E_ARGUMENT', 'Expected TimedEvents') unless validate_events($events) eq 'duration';
    return _convert($events, $rate / 1_000_000, 'samples', {sample_rate => $rate});
}

sub to_timed {
    my ($events) = @_;
    fail('CW_E_ARGUMENT', 'Expected SampledEvents') unless validate_events($events) eq 'samples';
    return _convert($events, 1_000_000 / $events->{sample_rate}, 'duration', {unit => 'us'});
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::Events - validate and convert canonical event sequences

=head1 SYNOPSIS

    use Ham::CW::Events qw(to_samples to_timed validate_events);
    my $sampled = to_samples($timed, 16000);
    my $timed_again = to_timed($sampled);

=head1 FUNCTIONS

=head2 validate_events

C<validate_events(events)> checks a hash containing C<segments>, plus either
C<unit =E<gt> 'us'> or C<sample_rate>. It returns C<duration> or C<samples>.
Each segment has C<state> (C<on>/C<off>) and a positive integer duration.
States alternate; empty sequences and leading/trailing silence are valid.
Rates range from 1000 to 384000. Total duration is limited to 2**52 units.

=head2 to_samples

C<to_samples(timed, rate)> and C<to_timed(sampled)> return fresh hashes.
Cumulative boundaries round to nearest integer, with halves upward; rounding
never accumulates per-segment drift. A zero-length output segment raises
C<CW_E_TIMING>. Conversion back is lossy within the selected resolution.
No function mutates its input.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
