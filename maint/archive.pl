#!/usr/bin/env perl
use 5.020;
use strict;
use warnings;
use Carp qw(croak);
use Archive::Tar;
use ExtUtils::Manifest qw(maniread);

my ($output, $directory) = @ARGV;
die "Usage: perl maint/archive.pl OUTPUT.tar DIST_DIRECTORY\n"
    unless defined($directory) && -d $directory;
my $manifest = maniread("$directory/MANIFEST");
my @files    = map { "$directory/$_" } sort keys %{$manifest};
my $archive  = Archive::Tar->new;
$archive->add_files(@files);
for my $file ($archive->get_files) {
    $file->uid(0);
    $file->gid(0);
    $file->uname('');
    $file->gname('');
    $file->mode(($file->mode & oct '111') ? oct '755' : oct '644');
    $file->mtime($ENV{SOURCE_DATE_EPOCH}) if defined $ENV{SOURCE_DATE_EPOCH};
}
$archive->write($output) or croak "Cannot write $output: " . $archive->error;
