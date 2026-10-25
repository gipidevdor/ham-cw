# Installation

[Documentation](README.md) · [Overview](../README.md) · [Task guide](usage.md)

## Requirements

You need Perl 5.20 or later and ExtUtils::MakeMaker 7.22 or later. The newer
MakeMaker avoids an older build-tool search-path issue and supports
installation paths containing spaces; CPAN clients install it as a configure
prerequisite, while a manual build with an older bundled MakeMaker needs
`cpanm ExtUtils::MakeMaker` first.

## Build and install

From an extracted distribution or repository root:

```sh
perl Makefile.PL
make
make test
make install
```

Use the make program supplied with your Perl installation (`gmake` on some
Windows installations). The final command needs write permission to Perl's
library directory. For a user-owned destination, configure with
`perl Makefile.PL INSTALL_BASE=/your/install/directory` and include its
`lib/perl5` directory in `PERL5LIB` when running applications.

To use a checkout without installing, run scripts from the repository root
with `perl -Ilib script.pl`. The CPAN distribution name is `Ham-CW`, the Perl
package is `Ham::CW`, and this repository is named `ham-cw`.

## Verify the installation

```sh
ham-cw --version
ham-cw encode "SOS"
perldoc Ham::CW
```

The conversion prints `... --- ...`. If the command is not found, check that
Perl's installation `bin` directory is on `PATH`. For a checkout, use
`perl -Ilib bin/ham-cw --version` from the repository root.
