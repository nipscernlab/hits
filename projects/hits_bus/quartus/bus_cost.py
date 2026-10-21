"""What the configuration bus costs: hits against hits_bus, synthesized the same way.

A record of the measure of 2026-10-21 (bus_cost.txt): it needs a tree where both tops
exist, as commit 4f70075. Since then hits_bus is hits and the lean hits is gone, so on
today's tree it does not run.

Each top is compiled out of context in Quartus for the Cyclone V of the DE10-Nano
(5CSEBA6U23I7), every port on a virtual pin and a 25 ns clock, so the bus stays driven
from outside and nothing of it can be optimized away. Two configurations: the default
(F34 shaper) and the revised paper (USE_SHAPER_CSA_CR4RC, Lorenzetti energy ROM).

    python bus_cost.py [path of hits] [--quartus C:/intelFPGA_lite/24.1std/quartus/bin64]

About 10 minutes per compilation, four in all. The table goes to bus_cost.txt beside
this script.
"""
import argparse, re, shutil, subprocess, tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
ap = argparse.ArgumentParser()
ap.add_argument("hits", nargs="?", default=str(here.parents[2]))
ap.add_argument("--quartus", default="C:/intelFPGA_lite/24.1std/quartus/bin64")
a = ap.parse_args()
HITS, Q = Path(a.hits), Path(a.quartus)

CONFIGS = [("default (F34)", [], None),
           ("paper R1 (CSA, Lorenzetti)", ["USE_SHAPER_CSA_CR4RC=1"], "energy_seg_lorenzetti.mif")]


def num(txt, key):
    return float(re.search(key + r" : ([\d,.]+)", txt).group(1).replace(",", ""))


def fmax(sta):
    return min(float(x) for x in
               re.findall(r"Slow 1100mV [-\d]+C Model Fmax Summary.*?\n(?:.*\n){3}; ([\d.]+) MHz", sta))


rev = subprocess.run(["git", "-C", str(HITS), "log", "-1", "--format=%h %cs"], capture_output=True, text=True).stdout.strip()
if subprocess.run(["git", "-C", str(HITS), "status", "--porcelain", "rtl"], capture_output=True, text=True).stdout.strip():
    rev += " + uncommitted changes in rtl/"
lines = [f"hits {rev}, Quartus in {Q}, 5CSEBA6U23I7, out of context, virtual pins, 25 ns",
         f"{'configuration':28s} {'top':9s} {'ALMs':>6s} {'regs':>6s} {'M10K':>5s} {'DSP':>4s} {'Fmax':>10s}"]
print(lines[0], flush=True)
work = Path(tempfile.mkdtemp(prefix="bus_cost_"))
for cname, macros, seg in CONFIGS:
    for top in ("hits", "hits_bus"):
        d = work / f"{top}_{len(macros)}"
        d.mkdir()
        for m in (HITS / "rtl").glob("*/*.mif"):
            shutil.copy(m, d)
        (d / "c.sdc").write_text("create_clock -name clk -period 25.000 [get_ports clk]\nderive_clock_uncertainty\n")
        src = sorted((HITS / "rtl").glob("*.v")) + sorted((HITS / "rtl").glob("*/*.v"))
        tcl = ["project_new c -overwrite", 'set_global_assignment -name FAMILY "Cyclone V"',
               "set_global_assignment -name DEVICE 5CSEBA6U23I7",
               f"set_global_assignment -name TOP_LEVEL_ENTITY {top}",
               "set_global_assignment -name SDC_FILE c.sdc",
               "set_instance_assignment -name VIRTUAL_PIN ON -to *",
               "set_instance_assignment -name VIRTUAL_PIN OFF -to clk"]
        tcl += [f'set_global_assignment -name VERILOG_FILE "{p.as_posix()}"' for p in src]
        tcl += [f'set_global_assignment -name VERILOG_MACRO "{m}"' for m in macros]
        if seg:
            tcl.append(f'set_parameter -name MEM_SEG "{seg}"')
        tcl.append("project_close")
        (d / "c.tcl").write_text("\n".join(tcl) + "\n")
        for args in (["-t", "c.tcl"], ["--flow", "compile", "c"]):
            r = subprocess.run([str(Q / "quartus_sh.exe"), *args], cwd=d, capture_output=True, text=True)
            if r.returncode:
                print(r.stdout[-3000:])
                raise SystemExit(f"{cname} {top}: Quartus failed")
        fit = (d / "c.fit.summary").read_text()
        alms = num(fit, r"Logic utilization \(in ALMs\)")
        lines.append(f"{cname:28s} {top:9s} {alms:6.0f} "
                     f"{num(fit, 'Total registers'):6.0f} {num(fit, 'Total RAM Blocks'):5.0f} "
                     f"{num(fit, 'Total DSP Blocks'):4.0f} {fmax((d / 'c.sta.rpt').read_text()):6.1f} MHz")
        print(lines[-1], flush=True)
(here / "bus_cost.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
shutil.rmtree(work, ignore_errors=True)
