#!/usr/bin/env python3
"""HITS regression: builds and runs every golden configuration and compares
each one bit-for-bit against its frozen baseline.

    python verification/regress.py                  # every build
    python verification/regress.py sim est          # a subset
    python verification/regress.py --create <build> # CREATE a missing golden

Two groups of builds, so a failure says WHAT broke:
  core            HITS ALONE, up to the ADC quantization (projects/hits/aurora/,
                  hits_tb.v, only rtl/ is compiled). If one fails, the CORE changed.
  reconstruction  HITS + the technique under test (projects/hits_reco/aurora/,
                  hits_reco_tb.v, rtl/ + reconstruction/). If only these fail,
                  the TECHNIQUE changed, not the core.

Exit 0 only if EVERY requested build is bit-identical to its golden AND no
step reports an error. A correct golden does not absolve a broken run: any
iverilog/vvp error -- including "$readmem: Unable to open" -- fails the build
even when the waveform matches (lesson of 2026-09-14, when the f34_est golden
turned out to freeze a run whose recip.mem was never read).

A vvp that DIES (non-zero exit, nothing on its output) is re-run up to twice
and listed at the end: on a machine short of memory the process gets killed
mid-simulation, with no error of its own (same finding as TODO item 15 of the
yanc repo). A complete but wrong waveform still fails at once.

--create writes the golden of a build that has none yet, from a clean run, and
refuses to overwrite an existing one: changing a golden is a decision made in
review, by hand, in the same commit as the change that justifies it.

Requires iverilog/vvp on PATH. Runs from any cwd.
"""
import glob
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERIF = os.path.join(ROOT, "verification")

# the two projects: folder (the simulation cwd), testbench, top, VCD it
# writes ($dumpfile is hardcoded in each tb) and what gets compiled
PROJECTS = {
    "core": (os.path.join(ROOT, "projects", "hits", "aurora"),
                  "hits_tb.v", "hits_tb", "hits_tb.vcd",
                  ("rtl/*.v", "rtl/*/*.v")),
    "reconstruction": (os.path.join(ROOT, "projects", "hits_reco", "aurora"),
                     "hits_reco_tb.v", "hits_reco_tb", "hits_reco_tb.vcd",
                     ("rtl/*.v", "rtl/*/*.v", "reconstruction/*.v",
                      "reconstruction/*/*.v")),
}

# name: (project, macros, golden)
# The default simulator is xoshiro + F34 shaper + segmented energy + Gaussian noise, sigma = 4 (no macro).
# The reconstruction group has no default technique: every build names the one
# it runs (pzc, est).
BUILDS = {
    # HITS alone, default generator (RNG_TYPE = "xoshiro")
    "sim":           ("core", [], "hits_tb_golden.vcd"),
    "sim_legacy":    ("core", ["USE_SHAPER_LEGACY"],
                      "hits_tb_golden_legacy.vcd"),
    "sim_csa_cr4rc": ("core", ["USE_SHAPER_CSA_CR4RC"],
                      "hits_tb_golden_csa_cr4rc.vcd"),
    # the three inverse-CDF noise tables with xoshiro (the default until 2026-10-02)
    "sim_noise_tables": ("core", ["USE_NOISE_TABLES"],
                      "hits_tb_golden_noise_tables.vcd"),
    # the three inverse-CDF energy tables with xoshiro (the default until 2026-10-08)
    "sim_energy_tables": ("core", ["USE_ENERGY_TABLES"],
                      "hits_tb_golden_energy_tables.vcd"),
    # the SBCCI 2025 generator (RNG_TYPE = "round_robin", default until 2026-09-28)
    "sim_round_robin": ("core", ["USE_RNG_ROUND_ROBIN"],
                      "hits_tb_golden_round_robin.vcd"),
    "sim_round_robin_legacy": ("core", ["USE_RNG_ROUND_ROBIN", "USE_SHAPER_LEGACY"],
                      "hits_tb_golden_round_robin_legacy.vcd"),
    # THE HITS OF FABIO'S SENSORS JOURNAL PAPER (tag paper-jsen-2026): round-robin
    # generator + CSA/CR-4RC shaper without its input register + the sigma = 8
# noise tables + the truncating ADC. Its golden is
    # FROZEN (see FROZEN).
    "paper":         ("core", ["USE_RNG_ROUND_ROBIN", "USE_SHAPER_CSA_CR4RC",
                                    "USE_NOISE_SIGMA8", "USE_ADC_FLOOR",
                                    "USE_SHAPER_NO_PIPE"],
                      "hits_tb_golden_paper.vcd"),
    # THE HITS OF THE REVISED PAPER (revision R1 of the Sensors Journal paper):
    # the current default with the CSA/CR-4RC shaper and the Lorenzetti energy
    # spectrum (energy_seg_lorenzetti.mif, occupancy 65530/65536). To be frozen once the
    # paper numbers close.
    "paper_r1":      ("core", ["USE_SHAPER_CSA_CR4RC", "USE_ENERGY_LORENZETTI"],
                      "hits_tb_golden_paper_r1.vcd"),
    # the leap-forward generator (RNG_TYPE = "leap")
    "sim_leap":      ("core", ["USE_RNG_LEAP"], "hits_tb_golden_leap.vcd"),
    "sim_leap_legacy": ("core", ["USE_RNG_LEAP", "USE_SHAPER_LEGACY"],
                      "hits_tb_golden_leap_legacy.vcd"),
    "sim_leap_csa_cr4rc": ("core", ["USE_RNG_LEAP", "USE_SHAPER_CSA_CR4RC"],
                      "hits_tb_golden_leap_csa_cr4rc.vcd"),
    # the phase of the pulse (2026-10-17), with the two shapers that have one: a fixed
    # phase of +8 steps (+3.125 ns) and a jitter per hit of sigma = 1 ns
    "sim_phase":     ("core", ["USE_PHASE0=8"], "hits_tb_golden_phase.vcd"),
    "sim_jitter":    ("core", ["USE_PHASE_SIGMA_PS=1000"], "hits_tb_golden_jitter.vcd"),
    "sim_phase_csa_cr4rc": ("core", ["USE_SHAPER_CSA_CR4RC", "USE_PHASE0=8"],
                      "hits_tb_golden_phase_csa_cr4rc.vcd"),
    "sim_jitter_csa_cr4rc": ("core", ["USE_SHAPER_CSA_CR4RC", "USE_PHASE_SIGMA_PS=1000"],
                      "hits_tb_golden_jitter_csa_cr4rc.vcd"),
    # HITS + technique; the wrapper instantiates the PZC when
    # USE_BASELINE_EST is not set
    "pzc":           ("reconstruction", [], "hits_reco_tb_golden_pzc.vcd"),
    "pzc_legacy":    ("reconstruction", ["USE_SHAPER_LEGACY"],
                      "hits_reco_tb_golden_pzc_legacy.vcd"),
    "pzc_csa_cr4rc": ("reconstruction", ["USE_SHAPER_CSA_CR4RC"],
                      "hits_reco_tb_golden_pzc_csa_cr4rc.vcd"),
    "est":           ("reconstruction", ["USE_BASELINE_EST"],
                      "hits_reco_tb_golden_est.vcd"),
}

# Goldens that must NEVER change: sha256 of the file with LF line endings.
# The paper build is the simulator outputs of tag paper-jsen-2026 delayed
# exactly one cycle (the testbench reset fix of 9dc32b2), checked signal by
# signal on 2026-09-28. A
# change of the RTL that alters it fails here even if someone regenerated the
# golden; changing this hash is a decision about the paper, not a fix.
FROZEN = {
    "hits_tb_golden_paper.vcd":
        # 2026-10-18: the testbench module and three of its localparams were renamed
        # (simulador_tb -> hits_tb, ORBITA -> ORBIT, N_ORBITAS -> N_ORBITS, N_CICLOS ->
        # N_CYCLES). The new file is the old one (c0a38647...) with only those names
        # changed, checked with the comparison of compare_vcd.py; every value is the same.
        "62ea349f7f7e656b00e11fe78104a71d8456354c758331c4c425ecc96aa82c85",
}

# where a choice can be left on by hand; the builds pass their own macros
# with -D, so every one of these must be committed with the lines commented
CHOICES = ("projects/hits_reco/aurora/choices.v", "rtl/hits.v",
            "reconstruction/hits_reco.v")

# builds run serially and every artifact is deleted before and after each one
# (a stale tb.vvp once produced a false OK -- F15 lesson, 2026-07-21)
VVP_NAME = "tb_regress.vvp"

ERROR_RE = re.compile(r"(?i)\berror\b|unable to open|vvp: can't", re.M)
ACTIVE_DEFINE_RE = re.compile(r"^\s*`define\b", re.M)
VVP_ATTEMPTS = 3          # the run plus two retries


def check_frozen():
    import hashlib
    for name, h in FROZEN.items():
        with open(os.path.join(VERIF, name), "rb") as f:
            # line endings normalized: a Windows checkout (autocrlf) gives CRLF,
            # the CI (Linux) gives LF, and the golden is the same
            if hashlib.sha256(f.read().replace(b"\r\n", b"\n")).hexdigest() != h:
                sys.exit("regress: the FROZEN golden %s changed (the HITS of the paper). "
                         "Restore it from git; it is never regenerated." % name)


def check_choices():
    """A `define left active in one of CHOICES would be added to every build."""
    active = []
    for rel in CHOICES:
        with open(os.path.join(ROOT, *rel.split("/")), encoding="utf-8") as f:
            active += ["%s: %s" % (rel, l.strip()) for l in f
                       if ACTIVE_DEFINE_RE.match(l)]
    if active:
        sys.exit("regress: a choice is active (%s).\nComment the line out before running "
                 "the regression or committing: each build passes its own "
                 "macros." % "; ".join(active))


def sources(project):
    folder, tb, _, _, patterns = PROJECTS[project]
    found_all = []
    for pattern in patterns:
        found = sorted(glob.glob(os.path.join(ROOT, *pattern.split("/"))))
        if not found:
            sys.exit("regress: no source matches %s" % pattern)
        found_all += found
    return found_all + [os.path.join(folder, tb)]


def artifacts(project):
    folder, _, _, vcd, _ = PROJECTS[project]
    return os.path.join(folder, vcd), os.path.join(folder, VVP_NAME)


def clean(project):
    for f in artifacts(project):
        if os.path.exists(f):
            os.remove(f)


def simulate(project, defines):
    """Builds and runs one configuration. Returns (error or None, retries)."""
    folder, _, top, _, _ = PROJECTS[project]
    VCD, VVP = artifacts(project)
    clean(project)
    cmd = ["iverilog", "-s", top, "-o", VVP]
    cmd += ["-D%s" % d for d in defines]
    cmd += sources(project)
    r = subprocess.run(cmd, cwd=folder, capture_output=True, text=True)
    if r.returncode != 0:
        return "iverilog failed:\n" + (r.stdout + r.stderr)[-2000:], 0

    for attempt in range(VVP_ATTEMPTS):
        if os.path.exists(VCD):
            os.remove(VCD)
        r = subprocess.run(["vvp", VVP], cwd=folder, capture_output=True, text=True)
        output = r.stdout + r.stderr
        m = ERROR_RE.search(output)
        if m:
            return ("error during simulation (a matching golden does not excuse it): %r"
                    % m.group(0)), attempt
        if r.returncode == 0:
            break
        # died without saying why: retry (TODO 15 of yanc); with an error
        # message it would have returned above
    else:
        return ("vvp died %d times in a row (exit code %d), with no message"
                % (VVP_ATTEMPTS, r.returncode)), VVP_ATTEMPTS - 1

    if not os.path.exists(VCD):
        return "the simulation wrote no VCD", attempt
    return None, attempt


def run(project, defines, golden):
    error, retries = simulate(project, defines)
    if error:
        clean(project)
        return error, retries
    VCD, _ = artifacts(project)
    r = subprocess.run([sys.executable, os.path.join(VERIF, "compare_vcd.py"),
                        VCD, os.path.join(VERIF, golden)],
                       capture_output=True, text=True)
    clean(project)
    if r.returncode != 0:
        return "different from the golden:\n" + (r.stdout + r.stderr)[-2000:], retries
    return None, retries


def create(names):
    for name in names:
        project, defines, golden = BUILDS[name]
        target = os.path.join(VERIF, golden)
        if os.path.exists(target):
            sys.exit("regress: %s exists; an existing golden changes only by hand, "
                     "in review" % golden)
        error, _ = simulate(project, defines)
        if error:
            clean(project)
            sys.exit("regress: %s not created, the run failed: %s" % (golden, error))
        shutil.move(artifacts(project)[0], target)
        clean(project)
        print("[CREATED] %-13s %s" % (name, golden))


def main():
    args = sys.argv[1:]
    create_mode = "--create" in args
    requested = [a for a in args if a != "--create"] or list(BUILDS)
    unknown = [p for p in requested if p not in BUILDS]
    if unknown:
        sys.exit("regress: unknown builds %s (valid: %s)"
                 % (unknown, ", ".join(BUILDS)))
    check_choices()
    check_frozen()
    if create_mode:
        create(requested)
        return

    failed, retried = [], []
    for name in requested:
        group, defines, golden = BUILDS[name]
        reason, retries = run(group, defines, golden)
        if retries:
            retried.append("%s (%dx)" % (name, retries))
        if reason:
            print("[FAILED] %-13s %-14s %s" % (name, group, reason))
            failed.append((name, group))
        else:
            print("[OK]     %-13s %-14s bit-identical to %s" % (name, group, golden))

    print("-" * 60)
    if retried:
        print("vvp run again (died with no message, short of memory?): %s"
              % ", ".join(retried))
    if failed:
        groups = {g for _, g in failed}
        if "core" in groups:
            print("THE CORE changed (rtl/): a build of HITS alone failed, "
                  "which only goes up to the ADC quantization.")
        else:
            print("Only builds with a technique failed: the core is intact, "
                  "the technique changed (reconstruction/).")
        print("regression: %d/%d builds FAILED: %s"
              % (len(failed), len(requested), ", ".join(n for n, _ in failed)))
        sys.exit(1)
    print("regression: %d/%d builds bit-identical to their goldens" %
          (len(requested), len(requested)))


if __name__ == "__main__":
    main()
