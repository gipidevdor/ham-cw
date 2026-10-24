# Contributing

Keep changes compatible with Perl 5.20. Runtime dependencies must be core
modules available there, unless a concrete need justifies an optional feature.
The symbolic decoder stays internal. Avoid platform-specific audio devices
and commands in the library.

Before changing behavior, add a test that distinguishes the old behavior from
the intended result. For DSP, use an independent signal source or a recorded
fixture with documented provenance. A generator/decoder round trip alone is
not enough. Do not commit recordings without permission to redistribute them.

## Local checks

```sh
perl Makefile.PL
make test
cpanm --installdeps --with-develop .
perlcritic lib Makefile.PL
prove -lr xt
make disttest
make dist
perl maint/check-dist.pl Ham-CW-0.001.tar.gz
```

The author checks require `META.yml` from `make distmeta` or `make dist`.
`.perlcriticrc` uses severity 3, including severity 4 and 5. The only source
suppressions are localized builtin-name exceptions for the public API names
`reset`, `state`, `read` and `write`. They do not change calls to Perl builtins.
Add any new exception here with its reason. Do not disable a policy to hide a
correctness or maintainability problem.

Use Perl::Tidy with the checked-in `.perltidyrc`; `xt/tidy.t` checks that the
result is unchanged. The CI author job pins the formatter version so a later
formatter release cannot silently redefine the repository style.

Coverage measures production modules, not tests. Use Devel::Cover and inspect
uncovered paths, particularly malformed input and incremental state handling.
The targets are 95% statements and 90% branches. Coverage does not replace
independent assertions or radio recordings.

Public API changes need POD, tests and a Changes entry. Preserve structured
error codes, validation atomicity and block-independent output. Resource
limits are part of the public contract. Keep metadata and MANIFEST in sync.
