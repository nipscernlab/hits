#!/usr/bin/env python3
"""HITS regression: builds and runs every golden configuration and compares
each one bit-for-bit against its frozen baseline.

    python verification/regress.py              # all four builds
    python verification/regress.py f34 csa_cr4rc  # a subset

Exit 0 only if EVERY requested build is bit-identical to its golden AND no
step reports an error. A correct golden does not absolve a broken run: any
iverilog/vvp error -- including "$readmem: Unable to open" -- fails the build
even when the waveform matches (lesson of 2026-09-14, when the f34_est golden
turned out to freeze a run whose recip.mem was never read).

Requires iverilog/vvp on PATH. Runs from any cwd.
"""
import glob
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AURORA = os.path.join(RAIZ, "projects", "aurora")
VERIF = os.path.join(RAIZ, "verification")

BUILDS = {
    "default":   ([], "sim_pulsos_tb_golden.vcd"),
    "f34":       (["USE_SHAPER_F34"], "sim_pulsos_tb_golden_f34.vcd"),
    "csa_cr4rc": (["USE_SHAPER_CSA_CR4RC"], "sim_pulsos_tb_golden_csa_cr4rc.vcd"),
    "f34_est":   (["USE_SHAPER_F34", "USE_BASELINE_EST"],
                  "sim_pulsos_tb_golden_f34_est.vcd"),
}

# the tb hardcodes $dumpfile("sim_pulsos_tb.vcd"), so builds run serially and
# every artifact is deleted before and after each one (a stale tb.vvp once
# produced a false OK -- F15 lesson, 2026-07-21)
VCD = os.path.join(AURORA, "sim_pulsos_tb.vcd")
VVP = os.path.join(AURORA, "tb_regress.vvp")

ERRO_RE = re.compile(r"(?i)\berror\b|unable to open|vvp: can't", re.M)


def fontes():
    lista = []
    for padrao in ("rtl/*.v", "rtl/filtros/*.v", "rtl_test/*.v",
                   "projects/aurora/sim_pulsos_tb.v"):
        achados = sorted(glob.glob(os.path.join(RAIZ, *padrao.split("/"))))
        if not achados:
            sys.exit("regress: nenhum fonte casa com %s" % padrao)
        lista += achados
    return lista


def roda(nome, defines, golden):
    for f in (VCD, VVP):
        if os.path.exists(f):
            os.remove(f)

    cmd = ["iverilog", "-s", "sim_pulsos_tb", "-o", VVP]
    cmd += ["-D%s" % d for d in defines]
    cmd += fontes()
    r = subprocess.run(cmd, cwd=AURORA, capture_output=True, text=True)
    saida = r.stdout + r.stderr
    if r.returncode != 0:
        return "iverilog falhou:\n" + saida[-2000:]

    r = subprocess.run(["vvp", VVP], cwd=AURORA, capture_output=True, text=True)
    saida = r.stdout + r.stderr
    if r.returncode != 0:
        return "vvp falhou:\n" + saida[-2000:]
    m = ERRO_RE.search(saida)
    if m:
        return "erro em tempo de simulacao (golden certo nao absolve): %r" % m.group(0)
    if not os.path.exists(VCD):
        return "a simulacao nao produziu o VCD"

    r = subprocess.run([sys.executable, os.path.join(VERIF, "compare_vcd.py"),
                        VCD, os.path.join(VERIF, golden)],
                       cwd=AURORA, capture_output=True, text=True)
    if r.returncode != 0:
        return "diferente do golden:\n" + (r.stdout + r.stderr)[-2000:]

    for f in (VCD, VVP):
        if os.path.exists(f):
            os.remove(f)
    return None


def main():
    pedidos = sys.argv[1:] or list(BUILDS)
    invalidos = [p for p in pedidos if p not in BUILDS]
    if invalidos:
        sys.exit("regress: builds desconhecidos %s (validos: %s)"
                 % (invalidos, ", ".join(BUILDS)))

    falhas = []
    for nome in pedidos:
        defines, golden = BUILDS[nome]
        motivo = roda(nome, defines, golden)
        if motivo:
            print("[FALHOU] %-10s %s" % (nome, motivo))
            falhas.append(nome)
        else:
            print("[OK]     %-10s bit-identico a %s" % (nome, golden))

    print("-" * 60)
    if falhas:
        print("regressao: %d/%d builds FALHARAM: %s"
              % (len(falhas), len(pedidos), ", ".join(falhas)))
        sys.exit(1)
    print("regressao: %d/%d builds bit-identicos aos goldens" %
          (len(pedidos), len(pedidos)))


if __name__ == "__main__":
    main()
