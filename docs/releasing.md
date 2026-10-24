# Release procedure

1. Review open bugs and API changes. Update the version consistently in public
   modules, Changes and documented examples. Check the changelog date.
2. Recheck CPAN index and PAUSE permissions for every public namespace. Obtain
   an authorized PAUSE account; repository ownership does not confer PAUSE rights.
3. Run the ordinary suite, author checks, formatter check and coverage. Inspect
   failures and the untested paths. Targets: 95% statement and 90% branch coverage.
4. Require every configured check on the exact candidate commit: the six
   ordinary Perl jobs, the five PDL configurations and the author/distribution
   job. Keep these twelve job names in main's required status checks. A configured
   matrix is not a test result.
5. Run `make dist`, `make disttest` and `make distcheck`. Inspect META.json,
   META.yml, MANIFEST and the archive contents. Check the archive
   with `perl maint/check-dist.pl Ham-CW-VERSION.tar.gz`. Verify installation
   with `perl maint/check-install.pl Ham-CW-VERSION.tar.gz`; it builds, tests,
   installs to a temporary prefix and runs the installed CLI, the three
   examples and the workflow tour. Verify the command and Windows launcher
   on the platform matrix too. Coverage collection must include every
   production module, including the optional PDL implementation. Install PDL
   for author verification; missing modules fail the gate. Collect one source
   tree per database so duplicated lib/blib paths cannot inflate the summary.
6. Review documented limitations. In particular, do not advertise field-proven
   DSP reception until an independently sourced, licensed recording corpus
   with expected text and signal conditions has passed.
7. Review CI results and the verification record. Do not substitute a CPANTS-like
   local check for a remote CPANTS or CPAN Testers report.
8. Obtain the maintainer's explicit approval for a CPAN upload. Upload manually
   or with the approved PAUSE tool; no workflow in this repository uploads.
9. After an accepted release, tag the tested commit, attach the distribution and
   checksum to a GitHub release, then monitor real CPAN Testers reports. Correct
   any attributable failures with regression tests and a subsequent release.

Do not place upload credentials in the repository. Development tools belong
in the author environment, not the runtime prerequisite list.
