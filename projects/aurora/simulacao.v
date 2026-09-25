// simulacao.v — WHICH SIMULATION RUNS. The only file to edit to choose it.
//
// Uncomment the lines you want, save, press Wave in Aurora. Nothing else
// changes: the testbench, the RTL and the Quartus project stay as they are.
//
// This file holds only `define lines and MUST be compiled FIRST (it is the
// first entry of synthesizableFiles in sim_pulsos.spf): Icarus applies a
// `define only to the files that come after it, and Aurora compiles the
// testbench last, which is why the choice cannot live in the testbench itself.
//
// Commit it with every line commented: the regression (verification/regress.py)
// passes the same macros with -D for each build and refuses to run while a
// line here is active, so a choice left on by accident cannot slip into a
// commit and make every golden look broken.
//
// ⚠️ Each combination has its own golden in verification/ (table in the
// README); the regression runs all of them.

// --- 1. What follows the simulator (at most ONE; none = simulator + PZC) ---
//`define SIMULATOR_ONLY          // the HITS simulator alone, no reconstruction technique
//`define USE_BASELINE_EST        // simulator + adaptive baseline estimator (calibrated for F34)

// --- 2. Shaper (at most ONE; none = legacy shaper_fenics) ---
//`define USE_SHAPER_F34          // 13-tap FIR + 5 IIR sections (FENICS, 14 poles)
//`define USE_SHAPER_CSA_CR4RC    // the generic "paper" pulse (CSA + CR-4RC)
