# GitHub Repository — PicoRadar

**Canonical remote:** `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
**Repository:** `sierraglobalcompany-rgb/PicoRadar`
**Visibility:** private
**Expected default branch:** `main`

## Approved C00 baseline

C00 was audited and approved by ChatGPT.

- Approved branch: `feat/C00-picoradar-repo-scaffold-flavors`
- Approved HEAD: `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`
- Worktree at handoff: clean
- Merge: none

The remote repository was empty when C01 kickoff was prepared.

## Bootstrap rule

Because the GitHub repository is empty and C00 is already approved, it is explicitly authorized to:

1. verify local HEAD/commit integrity;
2. connect `origin` to the canonical remote;
3. create local `main` pointing **exactly** to the approved C00 commit;
4. push `main`;
5. push the historical C00 feature branch if it exists;
6. create C01 branch from `main`.

This is an initial repository bootstrap, **not an autonomous merge**.

Do not rewrite/amend/rebase the approved C00 commit.

## C01 GitHub rule

After C01:
- push `feat/C01-app-shell-router`;
- open a PR to `main`;
- do not merge;
- include PR URL/number in handoff.
