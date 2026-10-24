# Contributing

Ham::CW supports Perl 5.20 or later. Keep the default backend dependent only
on core modules available with that Perl. Optional features must declare their
requirements separately. The public symbolic encoder/decoder are implemented
in this distribution; avoid mandatory external audio programs or device APIs.

## Set up a source checkout

Run commands from the repository root. Ordinary tests need the prerequisites
listed by `Makefile.PL`; they can run without PDL:

```sh
perl Makefile.PL
make
make test
```

Use your Perl's make program (`gmake` on some Windows installations). `prove -lr t`
is an alternative that reads `lib` directly and needs no installation.

Author checks additionally need PDL, Perl::Critic, the pinned Perl::Tidy release,
Devel::Cover and the POD/metadata tools declared under development prerequisites.
The following uses `cpanm` from App::cpanminus; if absent, install it first using
your Perl package manager or `cpan App::cpanminus`. These installation commands
need network access and a writable module installation directory.

```sh
cpanm --notest Perl::Tidy@20260826
cpanm PDL
cpanm --installdeps --with-develop .
perl Makefile.PL
make
make distmeta
prove -lr t xt
```

`make distmeta` creates the distribution metadata used by the author tests.
After another distribution command removes its staging directory, run it again
before repeating metadata checks. Source archives contain the formatter and
critic configurations needed for the same checks.

## Changing behavior

For a behavior fix, add a regression that distinguishes the old result from
the intended one. DSP tests should include an independent signal source or
a fixture with provenance, rather than relying only on generator/decoder
round trips. Recordings need redistribution permission. Keep error codes,
resource ceilings, validation atomicity and block-independent generation clear.

Use `perltidy -b path/to/file.pm` with `.perltidyrc`; the pinned formatter is
checked by `xt/tidy.t`. `xt/critic.t` uses `.perlcriticrc` severity 3 (including
levels 4 and 5). Existing source suppressions are narrow exceptions for public
names that match Perl builtins, such as `reset`, `state`, `read` and `write`.
Document any additional exception and its reason; do not disable a policy to
mask a correctness problem.

## Documenting the public API

POD embedded in each public module is the installed API reference. Every
public method/function needs its own `=head2` section, a signature, input and
return types, defaults/units/ranges, relevant errors and lifecycle behavior.
Each module needs a standalone `SYNOPSIS` with imports and initialized variables.
Define technical terms before using them; distinguish accepted ranges from
measured reception performance.

README and `docs/usage.md` are entry points and recipes. Their Perl code blocks
are standalone programs, not fragments relying on earlier examples. Keep
reference details in POD and link to them to avoid competing option tables.
`xt/documentation.t` checks method headings and executes all module synopses
and guide recipes independently in temporary directories with warnings fatal.
`xt/pod.t` validates POD syntax. Preview installed-style output with
`perldoc lib/Ham/CW.pm` or the corresponding module path.

## Coverage and release checks

Statement/branch targets are 95%/90% for all production modules, including PDL.
Install PDL for the full coverage gate. Use one consistent source tree per
database; do not mix old `blib` output with current `lib`. The CI workflow shows
the collection command and `maint/coverage.pl` validates both module inventory
and percentages. Coverage does not replace independent assertions or field data.

Public changes also need tests where appropriate and a concise `Changes` entry.
Keep `MANIFEST` and prerequisites synchronized. `make distcheck` reports missing
or unexpected files. See [release procedure](docs/releasing.md) for archive,
installation and publication checks. Submit changes through a pull request and
review all checks on the candidate commit; local tests alone do not establish
that another platform passes.
