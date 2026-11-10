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

## Repository setup

Workflow dependencies are recorded in `.github/workflows/actions.lock`. Run
`gh actions-lock --no-interactive` after changing a workflow and commit its
result; `gh actions-lock --verify` checks references against upstream and
`gh actions-lock --verify-local` checks coverage offline. The extension is
pinned in the verification workflow. Reusable workflow calls require separate
immutable pinning. Where GitHub workflow lock files are unsupported, replace
the version references with full commit hashes and verify the fallback before
applying policy.

The `actions-lock` and `gitleaks` jobs run on all protected pull requests.
The committed rulesets require them; confirm they report before applying those rulesets. Dependency
review fails on newly introduced high and critical findings; it requires the
dependency graph and may not be available for private repositories. For private
repositories, enable it only after validating availability by setting the
repository variable `ENABLE_DEPENDENCY_REVIEW` to `true`. The conditional job
is skipped otherwise: never require a skipped job as a security gate. Make the
job unconditional for the selected repository before requiring its context.
The workflow does not scan the entire resolved dependency tree for existing
vulnerabilities; additional ecosystem-specific scanning is still required.

Reviewed dependency-review exceptions are listed in
`.github/security-exceptions.json` as objects with a GHSA `id`, a nonempty
`reason`, and an `expires` date in YYYY-MM-DD. Empty list means no exceptions.
Each change goes through the protected PR review. The validation step rejects
invalid, duplicate, or expired exceptions. Expiry is evaluated by UTC date and
the exception remains valid through that date. Scope is the GHSA, not an
individual package or version; use the narrowest practical exception and
remove it when fixed. Exceptions do not apply to other scanners.

Dependabot groups minor and patch version updates by ecosystem; major version
updates remain separate. Independently review security updates and coordinate
packages that must move together. Dependabot targets the default branch unless
configured otherwise: set the default branch to `develop` during onboarding.
