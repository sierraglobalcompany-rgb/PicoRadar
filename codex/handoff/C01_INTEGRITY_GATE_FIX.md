# C01 Integrity Gate Fix

## Cause

The C01 handoff ZIP was created with `git archive`, which packages the committed Git blobs. On this Windows workspace, `core.autocrlf=true`; text files can be LF in the Git index/package while the working tree may be CRLF. The previous `SHA256SUMS.txt` and `manifest_sha256.txt` were generated from working-tree bytes, so text files with line-ending normalization produced mismatches when ChatGPT verified the ZIP/package bytes.

## Hash Contract

`SHA256SUMS.txt` and `manifest_sha256.txt` represent the final package bytes produced from Git, not mutable working-tree bytes. The two manifest files are intentionally excluded from their own entry list to avoid self-referential hashes.

## Verification

After this fix, both manifests were regenerated from the Git index bytes and verified against a fresh `git archive` ZIP with `0` mismatches.
