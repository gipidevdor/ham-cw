#!/bin/sh
# Original Ham::CW portability runner; Artistic License 2.0 (see LICENSE).
set -eu

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: sh .github/scripts/portability.sh EXPECTED_OS MAKE' >&2
    exit 2
fi
expected_os=$1
build_tool=$2

# Fail before building if a Windows or host Perl shadows the intended guest.
perl -e 'die "Wrong Perl platform: $^O (expected $ARGV[0])\n" if $^O ne $ARGV[0]' \
    "$expected_os"
perl -V

# Fetch a fixed upstream cpanm executable as a CI tool; it is not bundled in
# the distribution. Verify bytes before execution and use an HTTPS CPAN mirror.
mkdir -p .author/portability
cpanm=.author/portability/cpanm
curl --fail --location --retry 3 --silent --show-error \
    https://raw.githubusercontent.com/miyagawa/cpanminus/ef89524f68e1744897979896f9c2e92c7b161bbb/cpanm \
    --output "$cpanm"
perl -MDigest::SHA=sha256_hex -e '
    open my $fh, "<:raw", $ARGV[0] or die $!;
    local $/;
    die "cpanm checksum mismatch\n" unless sha256_hex(<$fh>) eq
        "4c5dcaac65e0c3e6e4272fd0f5c0a9c9ebdcbb29cdf329b18478b52f6883071c";
' "$cpanm"
perl "$cpanm" --notest --skip-satisfied --mirror https://cpan.metacpan.org --mirror-only \
    'ExtUtils::MakeMaker~7.22'
perl "$cpanm" --notest --mirror https://cpan.metacpan.org --mirror-only --installdeps .

perl Makefile.PL
"$build_tool"
HARNESS_PERL_SWITCHES=-Mwarnings=FATAL,all "$build_tool" test
perl maint/check-cli-install.pl .author/portability/installed --build
