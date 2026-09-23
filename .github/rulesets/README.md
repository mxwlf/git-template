# Branch protection as code

The JSON files in this directory are this repository's GitHub **rulesets** —
branch protection — stored as code. Manage them from the repository root:

```sh
make rulesets-apply     # create/update the rulesets on GitHub
make rulesets-diff      # fail if GitHub no longer matches these files
make rulesets-export    # overwrite these files from GitHub (after a UI edit)
```

All three run [`scripts/github-rulesets.sh`](../../scripts/github-rulesets.sh),
which talks to `/repos/{owner}/{repo}/rulesets` via `gh api`. The `gh ruleset`
command group is read-only (`check`, `list`, `view`), so it cannot do this.

## What the shipped rulesets enforce

| | `main-protection` | `develop-protection` |
| --- | --- | --- |
| Enforcement | `active` | `disabled` |
| Direct pushes | blocked — pull request required | blocked when enabled |
| Required check | `ci` (GitHub Actions) | `ci` (GitHub Actions) |
| Branch must be up to date | yes | yes |
| Approvals | 1, admins may bypass in a PR | 1 |
| Merge methods | rebase only | merge, squash, rebase |
| Signed commits | required | not required |
| Force push / deletion | blocked | blocked |

`develop-protection` ships **disabled** so that a new project can commit
straight to `develop` while it finds its feet. Flip `enforcement` to `active`
in the JSON and run `make rulesets-apply` when you want pull requests there too.

Two consequences of `main-protection` worth knowing before you enable it on a
project:

- **Merges must happen through GitHub.** Direct pushes to `main` are blocked, and
  with `required_signatures` the merge commits must be signed — GitHub signs the
  ones it creates itself. A local rebase-and-push will be rejected.
- **The admin bypass is real.** `bypass_mode: "pull_request"` lets an admin merge
  a pull request whose `ci` check is red. It prevents an accidental merge, not a
  deliberate one. Remove the `bypass_actors` entry if you want the check to be
  absolute — but on a single-maintainer repo that also makes
  `required_approving_review_count: 1` unsatisfiable, since you cannot approve
  your own pull request.

## The required check must actually run

A required status check that is never reported is never green, so the pull
request waits on it forever. The `context` value here (`ci`) is the **job id**
in [`.github/workflows/ci.yml`](../workflows/ci.yml), and that workflow's
`pull_request` trigger has to include every branch these rulesets protect. If
you rename the job, or add a protected branch, update both files together.

## What is portable between repositories

These files are meant to be copied into repos created from this template, so
they only reference ids that mean the same thing everywhere:

- **`integration_id: 15368`** in `required_status_checks` is the GitHub Actions
  app — a global app id, identical in every repository.
- **`actor_type: "RepositoryRole"`, `actor_id: 5`** is the repository admin
  role. Role ids are global too.

Do **not** commit rulesets that reference `actor_type: "Team"` or specific
users: those ids are scoped to one organization or account and will resolve to
the wrong thing, or fail, in another repo.

Ruleset **ids** are likewise per repository, which is why `apply` matches on the
`name` field instead. Rename a ruleset in one of these files and the next
`apply` creates a second one rather than renaming the original.

## Why these targets are not part of `make ci`

Rulesets are admin API surface. A workflow's default `GITHUB_TOKEN` cannot read
them and cannot be granted the rights via `permissions:`, so a `rulesets-diff`
step in CI would fail for reasons that have nothing to do with the code under
test — and it would break the rule that `make ci` behaves the same on a laptop
as in a pipeline. Run these locally, or from a workflow with an admin PAT if you
want drift detection enforced.

## Editing

JSON has no comments. `scripts/github-rulesets.sh` strips any key beginning with
`_`, so a `"_comment"` key in these files is harmless — but `make rulesets-export`
regenerates them verbatim from the API and will drop it. Durable explanation
belongs in this file.

If you change protection in the GitHub UI, run `make rulesets-export` to bring
the change back into the repo; otherwise the next `make rulesets-apply` will
silently revert it.
