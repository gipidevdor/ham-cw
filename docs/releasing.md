# Release procedure

[Overview](../README.md) · [Task guide](usage.md) · [Examples](../examples/README.md) · [Contributing](../CONTRIBUTING.md)

Run from a clean source checkout using the candidate Perl environment. Use
its make program (`gmake` on some Windows installations). Publication is a
separate maintainer action; no repository workflow uploads to CPAN.

1. Set the intended version in public modules and `Changes`. Check the release
   date and make sure the notes describe shipped behavior. Review README, task
   recipes and POD together. Confirm example filenames, option defaults and
   supported formats against the candidate code.
2. Check CPAN index/PAUSE permissions for every public namespace with an
   authorized PAUSE account. Repository ownership does not grant upload rights.
   Store credentials outside the repository.
3. Follow [contributing](../CONTRIBUTING.md) to install ordinary and author
   dependencies. Run `perl Makefile.PL`, `make`, `make distmeta` and
   `prove -lr t xt`. This includes syntax/style checks and independently
   executed documentation examples. Review rendered `perldoc` output as well.
4. Collect production coverage with PDL installed. Require every expected
   module and one source path per module, with at least 95% statement and
   90% branch coverage. Use a fresh database after changing source. The
   configured commands are in `.github/workflows/test.yml`; validate the
   result with `perl maint/coverage.pl COVERAGE_DIRECTORY`.
5. Review every configured CI job on the exact candidate commit, including
   ordinary Perl, current/minimum PDL combinations and author/distribution
   checks, plus any separately configured security workflow. Derive the job list from the current workflow; do not rely on an
   older job count. Review pending/failing checks before publication. Update
   any branch protection configuration separately if job names change.
6. Run `make distcheck`, `make disttest` and `make dist`. Inspect the archive,
   `MANIFEST`, `META.json` and `META.yml`. The resulting archive is named
   `Ham-CW-VERSION.tar.gz`; replace `VERSION` with the actual release version
   in the commands below. It must include public POD, task recipes, tests
   and author configurations, while excluding GitHub configuration and build
   output.

   ```sh
   perl maint/check-dist.pl Ham-CW-VERSION.tar.gz
   perl maint/check-install.pl Ham-CW-VERSION.tar.gz
   ```

   The installation check extracts/builds/tests in a temporary directory,
   installs to a temporary prefix and runs the installed CLI, command-line examples
   and workflow tour. It does not publish anything. Rerun `make distmeta`
   before author metadata checks if distribution commands removed staging data.
7. Check every distributed audio file against the reviewed license inventory.
   Preserve author/work titles, source links, change descriptions and license
   texts; original project licensing must not override third-party audio terms.
   The corpus-license author check rejects unregistered distributed recordings.
   Local recordings with unknown provenance must remain outside the archive.
8. Update [verification](verification.md) with the source revision, commands,
   environment and actual outcomes. Refresh `docs/current-results.json`,
   `docs/platform-results.json`, `docs/benchmarks.md`, `docs/verification.md`
   and corpus claims together.
   Record the measured source revision, input hashes, commands and timer type;
   run timing workloads without concurrent verification. Keep historical
   records explicitly archived and mark checks not rerun. A synthetic corpus does not establish off-air
   accuracy; local archive indicators are not CPAN Testers or remote CPANTS.
9. Obtain the maintainer's approval to upload the checked archive to CPAN.
   Use the authorized PAUSE process. Record the uploaded archive checksum and
   verify that it corresponds to the reviewed source.
10. After acceptance, tag the tested commit and publish the distribution and
   checksum through the project's release process. Review CPAN Testers reports;
   fix attributable failures with regressions and a subsequent release.

The ordinary platform matrix also runs `maint/check-cli-install.pl` to verify
the installed executable and Windows launcher, including paths with spaces.
