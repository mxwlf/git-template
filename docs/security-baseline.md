# Security and dependency baseline

This document records the recommended shared policy and the current starting
point for alignment. It is not a claim that every check is already installed or
required. Apply only checks that are available for the repository, configured
for its ecosystem, and verified to run on each protected pull request.

| Concern | Baseline direction | Current example |
| --- | --- | --- |
| Permissions | Pull-request jobs use read-only repository permissions. Grant write or identity-token permissions only to trusted jobs that need them. | Both the Git template CI and homepage CI explicitly declare read-only access. |
| Secrets | Run the shared local hook and scan relevant PR commits and repository history separately where supported. Avoid exposing secrets to untrusted code. | The Git template has a pre-commit Gitleaks hook; the homepage also has a repository-level workflow. |
| Dependencies | Review dependency changes on PRs and scan resolved dependencies for known vulnerabilities on PRs and on a schedule. Choose severity, scope, and exceptions deliberately. | The homepage uses dependency review and OSV; .NET packages and other ecosystems need their own accurate dependency scope. |
| Code scanning | Enable language-appropriate static security analysis and document where it runs and reports. Require it only if it actually reports meaningful results on every protected PR. | The homepage runs CodeQL outside PRs; a skipped PR job is not an effective required check. |
| Workflow dependencies | Pin or lock Actions dependencies to immutable commits and verify that workflow references are covered. Treat upstream identity and lockfile changes as reviewable supply-chain changes. | The homepage has an Actions lockfile and verification workflow. Its committed rulesets do not currently require `actions-lock`. |
| Updates | Propose regular updates to workflow dependencies and project packages. Review and test each update; group dependencies only when that tradeoff suits the project. | The homepage configures Dependabot for npm and Actions. A .NET project also needs an appropriate NuGet update policy. |
| Protection | Require the PR checks that genuinely run; keep rulesets as code, compare live configuration, and document bypass authority. | The shipped Git rulesets require `ci`. The homepage has additional gates and an account-specific promotion bypass. |

The Git template currently implements its existing hooks, read-only CI, and the
branch policies described in [the integration baseline](integration-release.md).
The other rows are proposed alignment work. The homepage and .NET template can
have additional checks and may need different tools; alignment does not mean
copying site-specific deployment settings or claiming that a missing check
passed.

Before making an additional check mandatory, verify its licensing and hosting
availability, PR triggers, permissions, fork behavior, initial results, and
failure mode. Enable and observe it first; then add its reported context to the
ruleset. Protecting a branch with a check that never runs can block merges,
while requiring a skipped job can create a permanently green non-gate.

The homepage's Actions lockfile verification runs on PRs and a schedule, but
its committed `main` and `develop` rulesets currently omit `actions-lock`.
Reconcile the intended requirement and the documentation, then inspect live
rules separately. Likewise, do not assume merging ruleset JSON applies it to
GitHub.
