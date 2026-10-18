`timescale 1ns/100ps

// Anchor generator for the adaptive baseline estimator.
//
// An ANCHOR is an ADC sample where the baseline is directly observable: a slot
// that has been empty long enough for the shaper's fast response to have died
// out completely. Measured upstream (F11 of the energy-reconstruction research):
// +93 ADC at gap+2, +0.87 at gap+5, EXACTLY 0 at gap+13: 13 slots is the
// length of the shaper's FIR head.
//
// The bunch-train mask is known, so anchors are derived from it and no
// threshold detection is needed. With the Run-3 mask this yields 654 anchors
// per orbit (18.4%), in 24 blocks.
//
// ⚠️ ALIGNMENT: `bt_mask_out` marks the slot where a hit is INJECTED, but the
// digitized sample only reflects it after the shaper pipeline. LATENCY shifts
// the anchor flag to the ADC time base. It is a PARAMETER and not a constant
// because it depends on which shaper is built (legacy, F34 or CSA+CR-4RC;
// see the SHAPER COMBINATIONS warning in hits_reco.v): sweep it
// and measure, do not guess. Wrong alignment does not raise an error: it silently
// feeds the estimator samples that still carry pulse, biasing the baseline.

module anchor_generator
#(
	parameter integer K_EMPTY  = 13,   // empty slots required before a sample counts
	parameter integer LATENCY = 6     // shaper pipeline delay, in samples; default = the
	                                   // F34-calibrated value (other shapers: re-measure,
	                                   // see the wrapper warning)
)
(
	input  wire clk,
	input  wire rst,
	input  wire bt_mask,               // 1 = filled slot (from bunch_train_mask)
	output wire anchor
);

	localparam integer WC = $clog2(K_EMPTY + 2);

	reg [WC-1:0] count = 0;             // consecutive empty slots
	reg          anc_r = 0;

	always @(posedge clk) begin
		if (rst) begin
			count  <= 0;
			anc_r <= 0;
		end else if (bt_mask) begin
			count  <= 0;
			anc_r <= 1'b0;
		end else begin
			if (count <= K_EMPTY) count <= count + 1'b1;
			anc_r <= (count + 1'b1 >= K_EMPTY);
		end
	end

	// LATENCY = 0 uses anc_r directly (it already carries one register stage).
	// ⚠️ LATENCY = 1 needs its own branch: the shift-register form would ask
	// for pipe[-1:0], which is a reversed part select and an elaboration error.
	generate
		if (LATENCY == 0) begin : no_delay
			assign anchor = anc_r;
		end else if (LATENCY == 1) begin : one_stage
			reg pipe1 = 0;
			always @(posedge clk) begin
				if (rst) pipe1 <= 1'b0;
				else     pipe1 <= anc_r;
			end
			assign anchor = pipe1;
		end else begin : delayed
			reg [LATENCY-1:0] pipe = 0;
			always @(posedge clk) begin
				if (rst) pipe <= 0;
				else     pipe <= {pipe[LATENCY-2:0], anc_r};
			end
			assign anchor = pipe[LATENCY-1];
		end
	endgenerate

endmodule
