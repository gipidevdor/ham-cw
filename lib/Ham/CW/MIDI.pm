package Ham::CW::MIDI;
use 5.020;
use strict;
use warnings;
use Scalar::Util                 qw(openhandle);
use Ham::CW::Events              qw(validate_events);
use Ham::CW::_Internal::IO       qw(write_bytes with_file);
use Ham::CW::_Internal::Validate qw(fail integer number options named_arguments);
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(note velocity channel program bpm ppqn max_bytes));
    return bless {
        note      => integer('note',     $args{note}     // 77,  0, 127),
        velocity  => integer('velocity', $args{velocity} // 100, 1, 127),
        channel   => integer('channel',  $args{channel}  // 1,   1, 16),
        program   => integer('program',  $args{program}  // 80,  0, 127),
        bpm       => number('bpm', $args{bpm} // 120, 4, 1000),
        ppqn      => integer('ppqn',      $args{ppqn}      // 480,     1,  32767),
        max_bytes => integer('max_bytes', $args{max_bytes} // 8000000, 64, 64000000),
    }, $class;
}

sub _vlq {
    my ($value) = @_;
    fail('CW_E_TIMING', 'MIDI delta exceeds four-byte VLQ range') if $value > 0x0fff_ffff;
    my @bytes = ($value & 0x7f);
    while ($value >>= 7) { unshift @bytes, ($value & 0x7f) | 0x80 }
    return pack('C*', @bytes);
}

sub encode {
    my ($self, $events) = @_;
    my $field = validate_events($events);
    my $tempo = int(60_000_000 / $self->{bpm} + 0.5);

    # Keep the original event units until the final tick boundary.
    my $numerator   = $self->{ppqn} * ($field eq 'samples' ? 1_000_000 : 1);
    my $denominator = $tempo * ($field eq 'samples' ? $events->{sample_rate} : 1);
    my $channel     = $self->{channel} - 1;
    my $track =
          "\0\xff\x51\x03"
        . substr(pack('N', $tempo), 1, 3)
        . pack('CCC', 0, 0xc0 | $channel, $self->{program});
    my ($time, $last_tick) = (0, 0);

    for my $segment (@{$events->{segments}}) {
        my $start = int($time * $numerator / $denominator + 0.5);
        $time += $segment->{$field};
        next if $segment->{state} eq 'off';
        my $end = int($time * $numerator / $denominator + 0.5);
        fail('CW_E_TIMING', 'MIDI resolution would produce a zero-length note') if $end <= $start;
        $track .= _vlq($start - $last_tick)
            . pack('CCC', 0x90 | $channel, $self->{note}, $self->{velocity});
        $track .= _vlq($end - $start) . pack('CCC', 0x80 | $channel, $self->{note}, 0);
        $last_tick = $end;
        fail('CW_E_RESOURCE', 'MIDI exceeds max_bytes') if length($track) + 30 > $self->{max_bytes};
    }
    $track .= _vlq(int($time * $numerator / $denominator + 0.5) - $last_tick) . "\xff\x2f\0";
    return pack('a4Nnnna4N', 'MThd', 6, 0, 1, $self->{ppqn}, 'MTrk', length $track) . $track;
}

sub write_file {
    my ($self, $path, $events, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, 'overwrite');
    my $overwrite = integer('overwrite', $args{overwrite} // 0, 0, 1);
    return with_file($path, 'write', sub { $self->write($_[0], $events) }, $overwrite);
}

sub write {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my ($self, $fh, $events) = @_;
    fail('CW_E_ARGUMENT', 'An open file handle is required') unless openhandle($fh);
    my $bytes = $self->encode($events);
    binmode($fh) or fail('CW_E_IO', 'Cannot set binary mode');
    write_bytes($fh, $bytes);
    return length $bytes;
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW::MIDI - standard MIDI file export without external modules

=head1 SYNOPSIS

    my $midi = Ham::CW::MIDI->new(note => 77, program => 80);
    open my $out, '>:raw', 'cq.mid' or die $!;
    $midi->write($out, $encoder->events('CQ'));
    close $out or die $!;

=head1 METHODS

=head2 new

C<new> accepts C<note> (77, range 0..127), C<velocity> (100, 1..127),
C<channel> (1, 1..16), C<program> (80, zero-based 0..127), C<bpm> (120,
4..1000), C<ppqn> (480, 1..32767) and C<max_bytes> (8000000).
General MIDI program 80 is a square lead; note 77 is about 698.46 Hz under
standard A440 tuning. Channel 10 is normally percussion; use a melodic
channel for a sustained CW tone. Actual sound and envelope depend on the
player and synthesizer, not on the file.

=head2 encode

C<encode(events)> returns a binary SMF type 0 file, with one track, a tempo
event, program change, explicit note-on/off events and end-of-track. It accepts
TimedEvents or SampledEvents. Cumulative boundaries round to nearest tick,
halves upward, using the encoded integer tempo and the original event units
without intermediate microsecond rounding. Leading/trailing silence is
preserved. Zero-tick notes or deltas above the SMF four-byte limit raise
C<CW_E_TIMING>. Output size is bounded; this is an atomic file exporter rather
than a live MIDI device interface. No synth, hardware, audio driver or MIDI
module is needed. C<write(handle, events)> validates/encodes before writing
and returns the number of bytes. The caller owns the handle.

=head2 write_file

C<write_file(path, events, overwrite =E<gt> 0)> exports custom timed or sampled events, closes
the owned file and returns the number of bytes. Existing paths are rejected
and preserved. Errors close the handle and attempt to remove newly created
output. Set C<overwrite =E<gt> 1> to explicitly replace an existing file via
a temporary sibling file; failed generation preserves the old contents.
For ordinary text, use L<Ham::CW/write_midi> instead.

=head2 Replacement file semantics

Explicit C<overwrite =E<gt> 1> preserves an existing regular destination's
permission bits. Symbolic-link destinations, including dangling links, are
rejected with C<CW_E_IO>. A new path follows the process umask. Replacement
uses a new file identity; ownership, ACLs and other hard links are not
transferred. See F<docs/architecture.md> for the shared file contract.

=head1 LICENSE

Artistic License 2.0. See F<LICENSE>.

=cut
