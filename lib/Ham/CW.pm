package Ham::CW;
use 5.020;
use strict;
use warnings;
use Ham::CW::Encoder;
use Ham::CW::Decoder;
use Ham::CW::Generator;
use Ham::CW::Detector;
use Ham::CW::Audio;
use Ham::CW::MIDI;
use Ham::CW::_Internal::Validate qw(fail options named_arguments);
our $VERSION = '0.001';

sub new {
    my ($class, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args,
        qw(wpm effective_wpm frequency sample_rate amplitude attack_ms release_ms unknown));
    my %encoder = map { exists($args{$_}) ? ($_ => $args{$_}) : () } qw(wpm effective_wpm unknown);
    my %generator = map { exists($args{$_}) ? ($_ => $args{$_}) : () }
        qw(frequency sample_rate amplitude attack_ms release_ms);
    Ham::CW::Encoder->new(%encoder);
    Ham::CW::Generator->new(%generator);
    return bless {encoder => \%encoder, generator => \%generator}, $class;
}
sub encode { my ($s, $text)  = @_; return Ham::CW::Encoder->new(%{$s->{encoder}})->encode($text) }
sub events { my ($s, $text)  = @_; return Ham::CW::Encoder->new(%{$s->{encoder}})->events($text) }
sub decode { my ($s, $morse) = @_; return Ham::CW::Decoder->new->decode($morse) }

sub generate_wav {
    my ($self, $text, $fh, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args, qw(bits max_bytes));
    my $events = $self->events($text);
    my $rate   = $self->{generator}{sample_rate} // 16000;
    require Ham::CW::Events;
    my $sampled = Ham::CW::Events::to_samples($events, $rate);
    my $count   = 0;
    $count += $_->{samples} for @{$sampled->{segments}};
    my $audio =
        Ham::CW::Audio->new(exists($args{max_bytes}) ? (max_bytes => $args{max_bytes}) : ());
    my $gen    = Ham::CW::Generator->new(%{$self->{generator}});
    my $next   = $gen->stream($sampled);
    my $writer = $audio->writer(
        $fh,
        sample_rate  => $rate,
        sample_count => $count,
        bits         => $args{bits} // 16
    );
    while (my $block = $next->()) { $writer->feed($block) }
    return $writer->finish;
}

sub generate_midi {
    my ($self, $text, $fh, @pairs) = @_;
    my %args = named_arguments(@pairs);
    return Ham::CW::MIDI->new(%args)->write($fh, $self->events($text));
}

sub decode_wav {
    my ($self, $fh, @pairs) = @_;
    my %args = named_arguments(@pairs);
    options(\%args,
        qw(frequency wpm effective_wpm stereo max_bytes min_frequency max_frequency frequency_step)
    );
    my %audio    = map { exists($args{$_}) ? ($_ => delete $args{$_}) : () } qw(stereo max_bytes);
    my $reader   = Ham::CW::Audio->new(%audio)->reader($fh);
    my $detector = Ham::CW::Detector->new(%args, sample_rate => $reader->{sample_rate});
    while (my $block = $reader->{next}->()) { $detector->feed($block) }
    return $detector->finish;
}
1;

=encoding UTF-8

=head1 NAME

Ham::CW - Morse text, timing and PCM tools in pure Perl

=head1 SYNOPSIS

    use Ham::CW;
    my $cw = Ham::CW->new(wpm => 20, frequency => 700);
    print $cw->encode('CQ CQ DE IU0HFJ'), "\n";
    print $cw->decode('... --- ...'), "\n";
    open my $out, '>:raw', 'cq.wav' or die $!;
    $cw->generate_wav('CQ CQ DE IU0HFJ', $out);
    close $out or die $!;
    open my $in, '<:raw', 'cq.wav' or die $!;
    my $result = $cw->decode_wav($in, frequency => 700, wpm => 20);
    print $result->text, "\n";

=head1 STATUS

Version 0.001 is an initial development release. Text/timing and PCM contracts
are specified; audio reception remains experimental. Minimum declared Perl is
5.20. See F<docs/verification.md> for versions and platforms actually tested.
No native libraries, external audio programs or network access are required.

=head1 METHODS

C<new> accepts C<wpm> (20), C<effective_wpm> (WPM), C<frequency> (700),
C<sample_rate> (16000), C<amplitude> (0.8), C<attack_ms> (5),
C<release_ms> (5), C<unknown> (error). Unknown options raise an exception.
These configure encoding/generation; reception takes its own optional hints.

C<encode(text)> returns Morse, C<decode(morse)> returns text, and
C<events(text)> returns TimedEvents. See L<Ham::CW::Encoder>,
L<Ham::CW::Decoder> and L<Ham::CW::Events> for syntax and rounding.

C<generate_wav(text, handle, bits =E<gt> 16, max_bytes =E<gt> 64000000)>
writes a mono PCM WAV in bounded blocks and returns writer statistics.
Handles are caller-owned; close them and check errors.

C<generate_midi(text, handle, %options)> writes a standard MIDI file. Options
are those of L<Ham::CW::MIDI>; defaults use MIDI note 77 (about 698 Hz),
independently of the audio oscillator frequency. WPM and Farnsworth timing
come from the encoder configuration. MIDI playback timbre depends on the player.

C<decode_wav(handle, %options)> reads a seekable WAV and returns
L<Ham::CW::Result>. Options: C<frequency>, C<wpm>, C<effective_wpm>,
C<stereo>, C<max_bytes>, C<min_frequency>, C<max_frequency>,
C<frequency_step>. Omit frequency/WPM for estimation. Always inspect warnings;
completion does not imply reliable reception. See L<Ham::CW::Detector>.

=head1 ERRORS

Fatal failures throw L<Ham::CW::Error>. Stable public codes:
C<CW_E_ARGUMENT>, C<CW_E_SYMBOL>, C<CW_E_TIMING>, C<CW_E_WAV_FORMAT>,
C<CW_E_WAV_TRUNCATED>, C<CW_E_IO>, C<CW_E_RESOURCE>, C<CW_E_STATE>,
C<CW_E_INTERNAL>. Recoverable reception anomalies are code/message hashes
in Result warnings. Validation errors leave incremental objects unchanged.

=head1 STREAMING

The generator exposes a pull iterator; the WAV reader also exposes a pull
iterator. WAV output, event decoding and detection use incremental feed and
finish. Results are snapshots. All accumulators have documented limits;
this version does not provide an unlimited-duration radio receiver. See the
individual modules for lifecycle rules and retained history.

=head1 AUTHOR

Giacomo Picchiarelli

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2026 Giacomo Picchiarelli.
Released under the Artistic License 2.0. See F<LICENSE>.

=cut
