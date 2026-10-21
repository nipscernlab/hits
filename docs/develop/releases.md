# Releases

A release of HITS is a version of the product: the RTL, the examples and the
manual of that version, published together. A release does not go out without
its manual.

## Versions

Versions follow [Semantic Versioning](https://semver.org/): a change that alters
the output of an existing build, or removes an option, increases the major
number; a new option that leaves every existing build as it was increases the
minor number; a fix that changes no output increases the patch number. The
version is in the file `VERSION` at the root, which this manual reads. Releases
are made from `main`, which carries the next version with the suffix `-dev`; a
branch `release/<major>.x` is opened only if an older major version needs a fix.

Table 1 shows the releases planned so far.

Table 1: releases of HITS.

| Version | What it is | Source |
|---|---|---|
| 1.0.0 | the first release: the HITS of the revised paper, with the phase of the pulse | `main` when the revised paper is resubmitted, on the same commit as the tag `paper-jsen-2026-r1` |

The versions of the papers are kept by their tags, not as releases:
`paper-jsen-2026` is the code of the submitted paper and `paper-jsen-2026-r1`
the code of the revision ([Papers](../guide/papers.md)).

The release `linux-image-v1` is not a version of HITS: it holds the operating
system image of the board with the ARM processor.

## What a release contains

- `hits-rtl-<version>.zip`: `rtl/`, the examples (`projects/aurora/`,
  `projects/de10_nano/`, `projects/zybo/` and the testbench
  `verification/testbenches/hits_tb.v`),
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
