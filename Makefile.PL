use 5.020;
use strict;
use warnings;
use ExtUtils::MakeMaker;
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
    META_MERGE    => {
        'meta-spec' => {version => 2},
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/gpicchiarelli/ham-cw.git',
                web  => 'https://github.com/gpicchiarelli/ham-cw'
            },
            bugtracker => {web => 'https://github.com/gpicchiarelli/ham-cw/issues'},
            homepage   => 'https://github.com/gpicchiarelli/ham-cw',
        },
        no_index => {directory => [qw(t xt examples maint)]},
        prereqs  => {
            develop => {
                requires => {
                    'Perl::Tidy'          => 0,
                    'Perl::Critic'        => 0,
                    'Devel::Cover'        => 0,
                    'Test::Pod'           => '1.48',
                    'Test::CPAN::Meta'    => 0,
                    'Test::CPAN::Changes' => 0,
                    'Test::Kwalitee'      => 0,
                }
            }
        },
    },
);
