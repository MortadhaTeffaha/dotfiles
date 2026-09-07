---
name: commit-signing
description: Rules for creating signed git commits in Datadog repositories. Required reading before any commit, push, or rebase in a ddoghq repo.
---

# Commit Signing Rules

Datadog repos use **SSH-based commit signing** managed by `git-config-tool`. The global git config sets:

- `gpg.format = ssh` — git signs with SSH keys, not GPG
- `commit.gpgSign = true` — every commit must be signed
- `user.signingKey = key::<ssh-public-key>` — the SSH key registered on GitHub
- The SSH agent is **1Password's SSH agent** (`SSH_AUTH_SOCK` points at 1Password)

For `ddoghq` repos (e.g. `dd-source`), a conditional `includeIf` block swaps in a different signing key registered on the `_ddog` GitHub account.

## Mandatory rules

1. **Never use `--no-gpg-sign`** or `-S=false` to bypass signing. If signing fails, the cause is almost always that 1Password is locked or the SSH agent cannot provide the key without interactive approval.

2. **If `git commit` fails with a signing error**, stop immediately and ask the user to unlock 1Password. Do not retry with `--no-gpg-sign`. Do not attempt to work around the failure.

3. **Never attempt manual re-signing** with `git rebase --exec 'git commit --amend --no-edit --gpg-sign'` or similar. This has caused PR corruption in the past (pulling in unrelated commits from main, bloating PRs from 3 commits to ~90).

4. **If commits are already unsigned**, use the `sign-pull-request` tool from the devtools repo:

   ```bash
   cd ~/go/src/github.com/DataDog/dd-source
   sign-pull-request -f -p -u --strategy squash -e https://github.com/ddoghq/dd-source/pull/<PR_NUMBER>
   ```

   Flags: `-f` skip confirmation, `-p` push automatically, `-u` skip version check, `--strategy squash` squash into one signed commit, `-e` use PR title without opening editor.

5. **Always let `commit.gpgSign = true` auto-sign**. Run `git commit` normally without any signing flags. The global config handles signing automatically when 1Password is unlocked.

## Quick reference

| Situation | Action |
|-----------|--------|
| `git commit` succeeds | Done — commit is signed automatically |
| `git commit` fails with signing error | Ask user to unlock 1Password, then retry the same command |
| Commits already unsigned | Use `sign-pull-request` — never manual rebase re-signing |
| Tempted to use `--no-gpg-sign` | Don't. Ask the user to unlock 1Password instead |
