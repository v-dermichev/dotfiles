# Global Instructions

## Git Commits

- NEVER add `Co-Authored-By: Claude` or any Claude/Anthropic metadata to commit messages
- NEVER include `🤖 Generated with Claude Code` or similar attribution lines
- Commits must reflect only actual human authors
- This applies to all projects, all repositories, and all git operations (including PRs, amends, rebases)

## CHANGELOG Versioning

- Before adding ANY CHANGELOG entry, check whether the top-of-CHANGELOG version is already released by looking for its tag on the remote: `git ls-remote --tags origin v<ver>` (or `git fetch --tags` then inspect).
- If the tag exists, that version is published and immutable — create a fresh version section above it (released `0.1.12` → new work goes in `0.1.13`).
- If the tag does not exist, the version is still pending — append to it.
- The tag is the deciding signal: don't create a new section just because work accumulated, and don't append to the top section just because it's there. Only released (tagged) versions are frozen. Applies to any versioned project.

## No Module-Level Code

- Don't write dangling module-level functions or executable/side-effecting statements when the logic has a natural home. Fold functions onto the class they operate on as `@staticmethod` / `@classmethod` (subclasses can override, namespace is explicit); keep setup inside functions/methods, not at import time.
- Module-level constants, type aliases, enums, and class/`__all__` definitions are fine — that IS idiomatic module scope. The rule targets functions and runtime logic, not declarations.
- Exceptions, where module scope is the only option: `conftest.py` fixtures/hooks, `__init__.py` re-export/shim code, framework-required module-level hooks (e.g. pytest plugin entrypoints). Use module level there without hesitation.
- When unsure, ask "does this belong to a class or a single caller?" — if yes, put it there; fall back to module scope only when no such home exists. Applies to any project.

## Never Discard Uncommitted Work

- NEVER run commands that discard working-tree state — `git checkout -- <path>`, `git restore`, `git reset --hard`, `git clean`, `git stash` (without pop), or overwriting/deleting a file — over anything you have not first backed up. Uncommitted, unstaged changes have no git object; once discarded they are UNRECOVERABLE (reflog and `git fsck` only recover staged/committed content). Editor local history is the user's only fallback, not yours to rely on.
- NEVER use a broad pathspec or glob (`*.py`, `.`, `-A`) with a discarding command — it sweeps up the user's unrelated unstaged work along with whatever you meant to revert.
- When a tool you ran (formatter, linter `--fix`, codegen) dirties files you did not intend to change, revert ONLY the specific paths that tool touched, and only after confirming the user has nothing unstaged there. If unsure whether work would be lost, STOP and ask first.
- No apology fixes destroyed uncommitted work. The bar is prevention: back up (copy/stash/commit) before any destructive operation, or don't run it. Applies to any project, any VCS.

## Code Comments — Current State Only

- NEVER write "before/after" framing in code comments or docstrings (e.g. "previously X, now Y", "used to be a bare dict", "ровно как раньше"). Describe only what the code IS now.
- The diff and git history already record what changed; transition-narrating comments become stale noise that misleads future readers.
- When documenting a refactor, write the comment as if the current design always existed — explain what it does and why, not what it replaced. Applies to any project, any language.

## PR Reviews — Pending Only, Never Submit

- NEVER submit a review to a pull request. Submitting is mine alone. This covers every review path: `/review`, `/code-review`, `/security-review`, and any ad-hoc `gh`/API call.
- FORBIDDEN commands: `gh pr review --approve`, `--request-changes`, `--comment` (all of these submit immediately and are recorded under my GitHub identity), and any `POST /repos/{owner}/{repo}/pulls/{n}/reviews` that includes an `event` field.
- The ONLY allowed way to put review content on a PR is a **pending** review: `POST /repos/{owner}/{repo}/pulls/{n}/reviews` with `body` and `comments` and **no `event` key**. GitHub stores it in state `PENDING`, visible only to me, until I submit it myself in the UI. Example:

  ```bash
  gh api repos/{owner}/{repo}/pulls/<n>/reviews --input review.json
  # review.json: {"commit_id": "<head sha>", "body": "...",
  #   "comments": [{"path": "src/x.cs", "line": 42, "side": "RIGHT", "body": "..."}]}
  ```

- **All comments must go in that one create call** — GitHub has no endpoint for adding a comment to an existing pending review. One pending review per PR per user: if `GET .../pulls/<n>/reviews` already shows a `PENDING` one of mine, either `PUT .../reviews/<review_id>` to replace its body, or `DELETE .../reviews/<review_id>` and recreate the whole payload. Never create a second.
- Never call `POST .../pulls/<n>/reviews/<review_id>/events` — that is the submit endpoint, mine to call, not yours.
- Standalone issue/line comments (`gh pr comment`, `POST .../issues/<n>/comments`, `POST .../pulls/<n>/comments`) post publicly and instantly — they are NOT a pending review. Do not use them as a workaround; fold the content into the pending review body instead.
- Default output stays local: unless I ask for the review to be put on the PR, just report findings in the conversation and post nothing. When you do create the pending review, say so plainly and tell me it is awaiting my submission.
