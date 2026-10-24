# Security checks in CI

`.github/workflows/security.yml` runs on pull requests, pushes to main,
manual dispatch and every Monday at 06:23 UTC. The weekly scan refreshes the
advisory database even when no code changes. The final **Security checks**
job fails unless every security job succeeds, including when another job is
skipped, fails to install a tool or cannot produce its report. Configure this
check as required in GitHub branch protection/rulesets to block merging;
adding a workflow alone does not change repository rules.

| Check | Scope and failure behavior |
| --- | --- |
| CPAN::Audit / CPANSA::DB | Installs runtime, recommended, test and author dependencies on Perl 5.44; audits all installed CPAN distributions, the interpreter, and declared dependency constraints. Any advisory or scanner error fails the job. |
| Gitleaks 8.30.1 | Scans the complete checked-out Git history, including earlier commits, without printing secret values. Findings fail the job. |
| actionlint 1.7.12 | Checks workflow structure, expressions and embedded shell scripts. |
| zizmor 1.31.1 | Checks workflow permissions, expression injection, credential persistence and action pinning in offline mode. |
| Perl::Critic security policies | Rejects string eval, two-argument open, bareword file handles and backtick shell execution in library, maintainer scripts, examples and Makefile.PL. |

CVE JSON artifacts are retained for 14 days. Redacted Gitleaks JSON is retained
for 7 days. Artifacts are attempted even after scanner failure. Scanner and
advisory database versions appear in job logs. No `continue-on-error`,
`--exit-zero`, vulnerability exclusion file or secret allowlist is configured.
The existing malformed-WAV, resource-limit, I/O-failure and lifecycle tests
remain in the ordinary test matrix.

## Pipeline and update policy

All actions are pinned to complete commit SHAs. Checkouts do not persist Git
credentials. Jobs have read-only repository access; the aggregate gate has no
permissions. Security checks use the normal pull-request event, without
privileged `pull_request_target`, repository secrets, or write tokens. Timeouts
bound every job. Gitleaks and actionlint are built from pinned Go module
versions using Go's checksum verification; zizmor is installed at a pinned
version in a temporary virtual environment (Python 3.11+ is required).
CPAN::Audit and CPANSA::DB deliberately update to the latest available release
on each run rather than freeze the vulnerability feed.

Dependabot checks pinned GitHub Actions weekly. Routine version updates have
a seven-day cooldown; GitHub documents that cooldown does not apply to
security updates. Review the pinned CLI scanner versions periodically; they
are not automatically updated by the GitHub Actions ecosystem integration.
CPAN auditing is separate from Dependabot because CPAN is not covered by
that ecosystem configuration.

## Limits and responses

A CVE match is a signal to review the exact version, vendor patches and input
conditions, not proof of exploitation in Ham::CW. Core Perl advisories may
require upgrading the interpreter or restricting the deployment environment;
changing Ham::CW's source does not patch the interpreter. Legacy Perl versions
in the compatibility matrix are not certified free of vulnerabilities by a
Perl 5.44 security run. Optional/native dependencies and newly disclosed
issues still require assessment.

The CPAN advisory database only knows recorded advisories and module-to-dist
mappings. A distribution absent from that database (currently including PDL
in the database used locally) is not independently certified safe. Installed
versions and constraints are audited where the database has entries. Tool or
network failures must be investigated, not converted to passing scans.

CodeQL does not support Perl source. Perl::Critic provides targeted source
checks, not full taint/dataflow analysis. zizmor runs without GitHub API access;
API-dependent checks such as commit provenance cannot be established offline.
These gates supplement code review and parser tests; they are not an exhaustive
security audit. Secrets detected in history require credential rotation and
review of exposure, even if the current source has removed them.

Any future exception needs an exact advisory/fingerprint, evidence explaining
why it does not apply, an owner and an expiry/review date. Do not add broad
exclusions to make the pipeline green.

## Local verification, 2026-10-24

actionlint 1.7.12 and zizmor 1.31.1 accept both workflows and Dependabot config.
Gitleaks 8.30.1 found no leaks in 21 commits or the local directory scan; output
was redacted. All four targeted Perl::Critic policies passed. Negative controls
confirmed that a synthetic credential is rejected with a redacted report, and
invalid/unsafe workflow fixtures make actionlint and zizmor exit nonzero.
Distribution metadata validation also passed.

CPAN::Audit 20260622.001 with CPANSA::DB 20260923.001 reported three advisory
matches in the local developer environment: CPANSA-perl-2026-15534,
CPANSA-File-Temp-2011-4116 and CPANSA-podlators-2026-82560. Both installed and
declared-dependency audits exit nonzero. No exclusions were added. These are
local database matches awaiting applicability review, not validated Ham::CW
vulnerabilities or results from the GitHub runner. The complete remote workflow
must run after these changes are pushed; its newly resolved dependency versions
and newer advisory database can produce different results.

## Run the checks locally

Use a disposable Perl environment to install the full dependency set and the
current CPAN::Audit/CPANSA::DB before interpreting results. The commands retain
nonzero exit status when advisories or errors occur:

```sh
cpan-audit --version
cpan-audit installed --perl --no-color --json
cpan-audit deps . --perl --no-color --json
gitleaks git --redact=100
actionlint
zizmor --offline --no-progress .github
for policy in ProhibitStringyEval ProhibitTwoArgOpen ProhibitBarewordFileHandles ProhibitBacktickOperators; do
    perlcritic --single-policy "$policy" lib maint examples Makefile.PL || exit 1
done
```

## Tool references

- [CPAN::Audit commands and exit codes](https://metacpan.org/pod/cpan-audit)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [zizmor usage and offline limitations](https://docs.zizmor.sh/usage/)
- [actionlint](https://github.com/rhysd/actionlint)
- [Dependabot cooldown](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#cooldown)
- [CodeQL supported languages](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/)
