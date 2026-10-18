# Releases

A release of HITS is a version of the product: the RTL, the examples and the
manual of that version, published together. A release does not go out without
its manual.

## Versions

Versions follow [Semantic Versioning](https://semver.org/): a change that alters
the output of an existing build, or removes an option, increases the major
number; a new option that leaves every existing build as it was increases the
minor number; a fix that changes no output increases the patch number. The
version is in the file `VERSION` at the root, which this manual reads. Each
major version has a branch `release/<major>.x`, where its releases and fixes are
made; `main` carries the next major version with the suffix `-dev`.

Table 1 shows the releases planned so far.

Table 1: releases of HITS.

| Version | What it is | Source |
|---|---|---|
| 1.0.0 | the HITS of the submitted paper | the tag `paper-jsen-2026`, with a manual of its own |
| 2.0.0 | the HITS of the revised paper | the branch `release/2.x` when the numbers of the revision are final and the golden of `paper_r1` is frozen |
| 3.0.0 | adds the phase of the pulse: a fixed phase and a jitter per hit | `main`, after 2.0.0 |

The release `linux-image-v1` is not a version of HITS: it holds the operating
system image of the board with the ARM processor.

## What a release contains

- `hits-rtl-<version>.zip`: `rtl/`, `projects/hits/` (the examples),
  `VERSION`, `LICENSE` and `README.md`;
- `hits-docs-<version>.zip`: this manual in HTML, for reading offline;
- the manual published at `nipscern.com/library/hits`.

## The checks before a release

A release is made by pushing a tag `v<version>`. The release workflow then
checks, and stops at the first failure:

1. the tag equals the content of `VERSION`;
2. the regression passes, every build identical to its golden;
3. the manual builds with every warning treated as an error (a broken link or a
   page outside the table of contents stops it).

Only then does it build the two archives, create the release with them and
publish the manual. Keeping the manual correct is part of every change, not of
the release: a change that makes a sentence of this manual untrue fixes the
sentence in the same commit. The manual is built in CI on every push for that
reason.
