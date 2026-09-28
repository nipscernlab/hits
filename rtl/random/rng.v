`timescale 1ns/100ps

// Pseudo-random word generator of the group's papers (SBCCI 2025): a bank of
// 7 LFSRs (lfsr42) with different seeds, read in round robin, one per clock
// cycle, which decorrelates consecutive words. Each stage of the simulator
// that draws something (hits, energy, noise) has its own rng with its own
// seeds.
//
// ROTATING BANK. Instead of 7 LFSRs standing still and a 7:1 multiplexer
// picking one per cycle, the 7 states rotate: at each clock, position p takes
// the next state of position p+1. Then position p holds LFSR (p+n) mod 7 at
// cycle n, so position 1 is always the LFSR the round robin reads next, and no
// multiplexer or selector counter is needed. The words are bit for bit those
// of the multiplexed bank (same seeds, same order: 1, 2, ..., 6, 0, 1, ...
// after reset); until 2026-09-28 it was built that way, with round_robin.v.
//
// Seeds are 42 bits. Until 2026-09-26 they were declared 64 bits wide and some
// instantiated seeds did not fit, so the value written was silently truncated
// to seed[41:0]; the instantiations now write the effective value (the
// originals are in the git history). A zero seed would freeze its LFSR: the
// simulation refuses it.
module rng
#(
	parameter RAND_OUT_SIZE = 7,
	parameter [41:0] SEED0 = 42'd461934351,
	parameter [41:0] SEED1 = 42'd363409739,
	parameter [41:0] SEED2 = 42'd209805534,
	parameter [41:0] SEED3 = 42'd3049884771,
	parameter [41:0] SEED4 = 42'd2859598492,
	parameter [41:0] SEED5 = 42'd352859598492,
	parameter [41:0] SEED6 = 42'd42859998594
)
(
	input clk, rst,
	output reg [RAND_OUT_SIZE-1:0] rand_out = 0,
	output [RAND_OUT_SIZE-1:0] rand_next   // rand_out of the next cycle
);

localparam N_LFSR = 7;
localparam [N_LFSR*42-1:0] SEEDS = {SEED6, SEED5, SEED4, SEED3, SEED2, SEED1, SEED0};

// position p = bits [p*42 +: 42]; reset (and power-up) puts LFSR p at position p
reg  [N_LFSR*42-1:0] bank = SEEDS;
wire [N_LFSR*42-1:0] bank_step;

genvar p;
generate
	for (p = 0; p < N_LFSR; p = p + 1) begin : pos
		// the LFSR now at position p+1 steps into position p
		lfsr42 step
		(
			.state(bank[((p + 1) % N_LFSR)*42 +: 42]),
			.next(bank_step[p*42 +: 42])
		);
	end
endgenerate

always @(posedge clk or posedge rst) begin
	if (rst)
		bank <= SEEDS;
	else
		bank <= bank_step;
end

// position 1 holds the LFSR that the round robin reads at the next edge
assign rand_next = bank[1*42 +: RAND_OUT_SIZE];

always @(posedge clk or posedge rst) begin
	if (rst)
		rand_out <= 0;          // back to the power-up value: a reset replays the run
	else
		rand_out <= rand_next;
end

// synthesis translate_off
integer k;
initial for (k = 0; k < N_LFSR; k = k + 1)
	if (SEEDS[k*42 +: 42] == 0) begin
		$display("ERROR: rng %m has a zero SEED%0d: that LFSR would never leave 0", k);
		$finish;
	end
// synthesis translate_on

endmodule
