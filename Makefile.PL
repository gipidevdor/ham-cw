use 5.020;
use strict;
use warnings;
use ExtUtils::MakeMaker;
my %provides;
for my $module (
    qw(Ham::CW Ham::CW::Encoder Ham::CW::Decoder Ham::CW::Events
    Ham::CW::Generator Ham::CW::Detector Ham::CW::Audio Ham::CW::MIDI
    Ham::CW::Result Ham::CW::Error)
    )
{
    my $file = "lib/$module.pm";
    $file =~ s{::}{/}gx;
    $provides{$module} = {file => $file, version => MM->parse_version($file)};
}
WriteMakefile(
    NAME               => 'Ham::CW',
    VERSION_FROM       => 'lib/Ham/CW.pm',
    ABSTRACT_FROM      => 'lib/Ham/CW.pm',
    AUTHOR             => 'Giacomo Picchiarelli',
    LICENSE            => 'artistic_2',
    MIN_PERL_VERSION   => '5.020',
    CONFIGURE_REQUIRES => {'ExtUtils::MakeMaker' => '6.64'},
    PREREQ_PM          =>
        {'Carp' => 0, 'Exporter' => 0, 'Scalar::Util' => 0, 'Storable' => 0, 'Hash::Util' => 0},
    TEST_REQUIRES => {'Test::More' => '0.98', 'File::Temp' => 0, 'JSON::PP' => 0, 'Symbol' => 0},
    dist          =>
        {TAR => '$(PERLRUN) maint/archive.pl', TARFLAGS => q{ }, COMPRESS => 'gzip -n -f --best'},
    META_MERGE => {
        provides    => \%provides,
        'meta-spec' => {version => 2},
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/gipidevdor/ham-cw.git',
                web  => 'https://github.com/gipidevdor/ham-cw'
            },
            bugtracker => {web => 'https://github.com/gipidevdor/ham-cw/issues'},
            homepage   => 'https://github.com/gipidevdor/ham-cw',
        },
        no_index => {directory => [qw(t xt examples maint)], namespace => ['Ham::CW::_Internal']},
        prereqs  => {
            develop => {
                requires => {
                    'Perl::Tidy'              => 0,
                    'Perl::Critic'            => 0,
                    'Devel::Cover'            => 0,
                    'Test::Pod'               => '1.48',
                    'Test::CPAN::Meta'        => 0,
                    'Test::CPAN::Changes'     => 0,
                    'Archive::Tar'            => 0,
                    'Module::CPANTS::Analyse' => '1.03',
                    'Test::Kwalitee'          => 0,
                }
            }
        },
    },
);
