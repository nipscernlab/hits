#!/usr/bin/env python3
"""HITS regression: builds and runs every golden configuration and compares
each one bit-for-bit against its frozen baseline.

    python verification/regress.py                  # every build
    python verification/regress.py sim f34_est      # a subset
    python verification/regress.py --gera <build>   # CREATE a missing golden

Two groups of builds, so a failure says WHAT broke:
  simulador     the HITS simulator ALONE, up to the ADC quantization
                (projects/aurora_simulador/, simulador_tb.v, only rtl/ is
                compiled), one per shaper. If one fails, the SIMULATOR changed.
  reconstrucao  simulator + the technique under test (projects/aurora/,
                sim_pulsos_tb.v, rtl/ + reconstrucao/). If only these fail,
                the TECHNIQUE changed, not the simulator.

Exit 0 only if EVERY requested build is bit-identical to its golden AND no
step reports an error. A correct golden does not absolve a broken run: any
iverilog/vvp error -- including "$readmem: Unable to open" -- fails the build
even when the waveform matches (lesson of 2026-09-14, when the f34_est golden
turned out to freeze a run whose recip.mem was never read).

A vvp that DIES (non-zero exit, nothing on its output) is re-run up to twice
and listed at the end: on a machine short of memory the process gets killed
mid-simulation, with no error of its own (same finding as TODO item 15 of the
yanc repo). A complete but wrong waveform still fails at once.

--gera writes the golden of a build that has none yet, from a clean run, and
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

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERIF = os.path.join(RAIZ, "verification")

# the two projects: folder (the simulation cwd), testbench, top, VCD it
# writes ($dumpfile is hardcoded in each tb) and what gets compiled
PROJETOS = {
    "simulador": (os.path.join(RAIZ, "projects", "aurora_simulador"),
                  "simulador_tb.v", "simulador_tb", "simulador_tb.vcd",
                  ("rtl/*.v", "rtl/*/*.v")),
    "reconstrucao": (os.path.join(RAIZ, "projects", "aurora"),
                     "sim_pulsos_tb.v", "sim_pulsos_tb", "sim_pulsos_tb.vcd",
                     ("rtl/*.v", "rtl/*/*.v", "reconstrucao/*.v",
                      "reconstrucao/*/*.v")),
}

# name: (project, macros, golden)
BUILDS = {
    "sim":           ("simulador", [], "simulador_tb_golden.vcd"),
    "sim_f34":       ("simulador", ["USE_SHAPER_F34"],
                      "simulador_tb_golden_f34.vcd"),
    "sim_csa_cr4rc": ("simulador", ["USE_SHAPER_CSA_CR4RC"],
                      "simulador_tb_golden_csa_cr4rc.vcd"),
    "default":       ("reconstrucao", [], "sim_pulsos_tb_golden.vcd"),
    "f34":           ("reconstrucao", ["USE_SHAPER_F34"],
                      "sim_pulsos_tb_golden_f34.vcd"),
    "csa_cr4rc":     ("reconstrucao", ["USE_SHAPER_CSA_CR4RC"],
                      "sim_pulsos_tb_golden_csa_cr4rc.vcd"),
    "f34_est":       ("reconstrucao", ["USE_SHAPER_F34", "USE_BASELINE_EST"],
                      "sim_pulsos_tb_golden_f34_est.vcd"),
}

# where a choice can be left on by hand; the builds pass their own macros
# with -D, so every one of these must be committed with the lines commented
ESCOLHAS = ("projects/aurora/simulacao.v", "rtl/FPGA_Simulator_v1.v",
            "reconstrucao/FPGA_Simulator_v1_PZC.v")

# builds run serially and every artifact is deleted before and after each one
# (a stale tb.vvp once produced a false OK -- F15 lesson, 2026-07-21)
VVP_NOME = "tb_regress.vvp"

ERRO_RE = re.compile(r"(?i)\berror\b|unable to open|vvp: can't", re.M)
DEFINE_ATIVO_RE = re.compile(r"^\s*`define\b", re.M)
TENTATIVAS_VVP = 3          # the run plus two retries


def confere_selecao():
    """A `define left active in one of ESCOLHAS would be added to every build."""
    ativas = []
    for rel in ESCOLHAS:
        with open(os.path.join(RAIZ, *rel.split("/")), encoding="utf-8") as f:
            ativas += ["%s: %s" % (rel, l.strip()) for l in f
                       if DEFINE_ATIVO_RE.match(l)]
    if ativas:
        sys.exit("regress: escolha ativa (%s).\nComente a linha antes de rodar "
                 "a regressao ou de commitar: cada build passa as proprias "
                 "macros." % "; ".join(ativas))


def fontes(projeto):
    pasta, tb, _, _, padroes = PROJETOS[projeto]
    lista = []
    for padrao in padroes:
        achados = sorted(glob.glob(os.path.join(RAIZ, *padrao.split("/"))))
        if not achados:
            sys.exit("regress: nenhum fonte casa com %s" % padrao)
        lista += achados
    return lista + [os.path.join(pasta, tb)]


def artefatos(projeto):
    pasta, _, _, vcd, _ = PROJETOS[projeto]
    return os.path.join(pasta, vcd), os.path.join(pasta, VVP_NOME)


def limpa(projeto):
    for f in artefatos(projeto):
        if os.path.exists(f):
            os.remove(f)


def simula(projeto, defines):
    """Builds and runs one configuration. Returns (error or None, retries)."""
    pasta, _, top, _, _ = PROJETOS[projeto]
    VCD, VVP = artefatos(projeto)
    limpa(projeto)
    cmd = ["iverilog", "-s", top, "-o", VVP]
    cmd += ["-D%s" % d for d in defines]
    cmd += fontes(projeto)
    r = subprocess.run(cmd, cwd=pasta, capture_output=True, text=True)
    if r.returncode != 0:
        return "iverilog falhou:\n" + (r.stdout + r.stderr)[-2000:], 0

    for tentativa in range(TENTATIVAS_VVP):
        if os.path.exists(VCD):
            os.remove(VCD)
        r = subprocess.run(["vvp", VVP], cwd=pasta, capture_output=True, text=True)
        saida = r.stdout + r.stderr
        m = ERRO_RE.search(saida)
        if m:
            return ("erro em tempo de simulacao (golden certo nao absolve): %r"
                    % m.group(0)), tentativa
        if r.returncode == 0:
            break
        # died without saying why: retry (TODO 15 of yanc); with an error
        # message it would have returned above
    else:
        return ("vvp morreu %d vezes seguidas (codigo %d), sem mensagem"
                % (TENTATIVAS_VVP, r.returncode)), TENTATIVAS_VVP - 1

    if not os.path.exists(VCD):
        return "a simulacao nao produziu o VCD", tentativa
    return None, tentativa


def roda(projeto, defines, golden):
    erro, repeticoes = simula(projeto, defines)
    if erro:
        limpa(projeto)
        return erro, repeticoes
    VCD, _ = artefatos(projeto)
    r = subprocess.run([sys.executable, os.path.join(VERIF, "compare_vcd.py"),
                        VCD, os.path.join(VERIF, golden)],
                       capture_output=True, text=True)
    limpa(projeto)
    if r.returncode != 0:
        return "diferente do golden:\n" + (r.stdout + r.stderr)[-2000:], repeticoes
    return None, repeticoes


def gera(nomes):
    for nome in nomes:
        projeto, defines, golden = BUILDS[nome]
        destino = os.path.join(VERIF, golden)
        if os.path.exists(destino):
            sys.exit("regress: %s ja existe; um golden existente so muda a mao, "
                     "em revisao" % golden)
        erro, _ = simula(projeto, defines)
        if erro:
            limpa(projeto)
            sys.exit("regress: %s nao gerado, a rodada falhou: %s" % (golden, erro))
        shutil.move(artefatos(projeto)[0], destino)
        limpa(projeto)
        print("[GERADO] %-13s %s" % (nome, golden))


def main():
    args = sys.argv[1:]
    modo_gera = "--gera" in args
    pedidos = [a for a in args if a != "--gera"] or list(BUILDS)
    invalidos = [p for p in pedidos if p not in BUILDS]
    if invalidos:
        sys.exit("regress: builds desconhecidos %s (validos: %s)"
                 % (invalidos, ", ".join(BUILDS)))
    confere_selecao()
    if modo_gera:
        gera(pedidos)
        return

    falhas, repetidos = [], []
    for nome in pedidos:
        grupo, defines, golden = BUILDS[nome]
        motivo, repeticoes = roda(grupo, defines, golden)
        if repeticoes:
            repetidos.append("%s (%dx)" % (nome, repeticoes))
        if motivo:
            print("[FALHOU] %-13s %-12s %s" % (nome, grupo, motivo))
            falhas.append((nome, grupo))
        else:
            print("[OK]     %-13s %-12s bit-identico a %s" % (nome, grupo, golden))

    print("-" * 60)
    if repetidos:
        print("vvp repetido (morreu sem mensagem, falta de memoria?): %s"
              % ", ".join(repetidos))
    if falhas:
        grupos = {g for _, g in falhas}
        if "simulador" in grupos:
            print("O SIMULADOR mudou (rtl/): falhou um build do simulador "
                  "sozinho, que vai so ate a quantizacao do ADC.")
        else:
            print("So builds com tecnica falharam: o simulador esta intacto, "
                  "mudou a tecnica (reconstrucao/).")
        print("regressao: %d/%d builds FALHARAM: %s"
              % (len(falhas), len(pedidos), ", ".join(n for n, _ in falhas)))
        sys.exit(1)
    print("regressao: %d/%d builds bit-identicos aos goldens" %
          (len(pedidos), len(pedidos)))


if __name__ == "__main__":
    main()
