use strict;
use warnings;
use Test::More;
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use Ham::CW;
use lib 't/lib';
use CorpusMetrics qw(character_error_rate);

is(character_error_rate('SOS', 'SOS'), 0, 'CER exact transcription');
cmp_ok(abs(character_error_rate('SOS', 'SXS') - 1 / 3),  '<', 1e-12, 'CER substitution');
cmp_ok(abs(character_error_rate('SOS', 'SS') - 1 / 3),   '<', 1e-12, 'CER deletion');
cmp_ok(abs(character_error_rate('SOS', 'SOOS') - 1 / 3), '<', 1e-12, 'CER insertion');
is(character_error_rate('A', 'AAAA'), 3, 'CER can exceed one with insertions');
open my $input, '<:raw', 'corpus/real.json' or die $!;
my $cases = JSON::PP->new->decode(do { local $/; <$input> });
close $input or die $!;
my @backends = ('perl');
push @backends, 'pdl' if eval { require Ham::CW::_Internal::PDL; 1 };

for my $case (@{$cases}) {
    open my $audio, '<:raw', $case->{file} or die $!;
    my $bytes = do { local $/; <$audio> };
    close $audio or die $!;
    is(sha256_hex($bytes), $case->{sha256},
        "$case->{name} fixture matches attributed source derivative");
    open my $header, '<:raw', \$bytes or die $!;
    my $info = Ham::CW::Audio->new->reader($header);
    close $header or die $!;
    is(
        $info->{sample_count},
        int(($case->{end_seconds} - $case->{start_seconds}) * $case->{sample_rate} + 0.5),
        "$case->{name} sample count matches its source crop"
    );
    is($info->{sample_rate}, $case->{sample_rate},
        "$case->{name} retains the documented sample rate");

    for my $backend (@backends) {
        my $result =
            Ham::CW->new(backend => $backend)->decode_wav_bytes($bytes, wpm => $case->{wpm});
        my $cer = character_error_rate($case->{reference}, $result->text);

        # The regression limit records today's shortcomings, not an accuracy claim.
        cmp_ok(
            $cer, '<=',
            $case->{max_regression_cer} + 1e-12,
            "$case->{name} / $backend does not increase the recorded CER"
        );
        note(
            sprintf(
                '%s / %s: CER %.3f, quality target %.2f, target %s',
                $case->{name}, $backend, $cer,
                $case->{quality_target_cer},
                $cer <= $case->{quality_target_cer} ? 'met' : 'NOT MET'
            )
        );
    }
}
done_testing;
