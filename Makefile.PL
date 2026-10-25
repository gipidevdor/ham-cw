use 5.020;
use strict;
use warnings;
use ExtUtils::MakeMaker 7.22;
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
    EXE_FILES          => ['bin/ham-cw'],
    CONFIGURE_REQUIRES => {'ExtUtils::MakeMaker' => '7.22'},
    BUILD_REQUIRES     => {'ExtUtils::MakeMaker' => '7.22'},
    PREREQ_PM          => {
        'Carp'           => 0,
        'Exporter'       => 0,
        'Scalar::Util'   => 0,
        'Storable'       => 0,
        'Hash::Util'     => 0,
        'File::Basename' => 0,
        'File::Temp'     => 0,
        'Fcntl'          => 0,
        'Encode'         => 0,
        'Getopt::Long'   => 0,
        'IO::Handle'     => 0,
        'JSON::PP'       => 0,
        'Text::Wrap'     => 0
    },
    TEST_REQUIRES => {
        'Test::More'  => '0.98',
        'JSON::PP'    => 0,
        'Symbol'      => 0,
        'Config'      => 0,
        'Cwd'         => 0,
        'IPC::Open3'  => 0,
        'File::Temp'  => 0,
        'File::Spec'  => 0,
        'Digest::SHA' => '5.96'
    },
    dist =>
        {TAR => '$(PERLRUN) maint/archive.pl', TARFLAGS => q{ }, COMPRESS => 'gzip -n -f --best'},
    META_MERGE => {
        provides       => \%provides,
        dynamic_config => 0,
        keywords       => [qw(morse cw amateur-radio wav midi)],
        'meta-spec'    => {version => 2},
        resources      => {
            repository => {
                type => 'git',
                url  => 'https://github.com/gipidevdor/ham-cw.git',
                web  => 'https://github.com/gipidevdor/ham-cw'
            },
            bugtracker => {web => 'https://github.com/gipidevdor/ham-cw/issues'},
            homepage   => 'https://github.com/gipidevdor/ham-cw',
        },
        no_index => {
            directory => [qw(xt examples maint lib/Ham/CW/_Internal)],
            namespace => ['Ham::CW::_Internal']
        },
        prereqs => {
            runtime => {recommends => {PDL => '2.081'}},
            develop => {
                requires => {
                    'Perl::Tidy'              => '20260826',
                    'Perl::Critic'            => 0,
                    'Devel::Cover'            => 0,
                    'Test::Pod'               => '1.48',
                    'Test::CPAN::Meta'        => 0,
                    'CPAN::Meta'              => 0,
                    'ExtUtils::Manifest'      => 0,
                    'Test::CPAN::Changes'     => 0,
                    'Archive::Tar'            => '3.10',
                    'Pod::Man'                => 'v6.1.1',
                    'CPAN::Audit'             => '20261013.002',
                    'PPI'                     => '1.291',
                    'Module::CPANTS::Analyse' => '1.03',
                    'Test::Kwalitee'          => 0,
                }
            }
        },
    },
);
