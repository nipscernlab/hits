`timescale 1ns/100ps

// Anchor generator for the adaptive baseline estimator.
//
// An ANCHOR is an ADC sample where the baseline is directly observable: a slot
// that has been empty long enough for the shaper's fast response to have died
// out completely. Measured upstream (F11 of the Reconstrucao_Energia vault):
// +93 ADC at gap+2, +0.87 at gap+5, EXACTLY 0 at gap+13 — 13 slots is the
// length of the shaper's FIR head.
//
// The bunch-train mask is known, so anchors are derived from it and no
// threshold detection is needed. With the Run-3 mask this yields 654 anchors
// per orbit (18.4%), in 24 blocks.
//
// ⚠️ ALIGNMENT: `bt_mask_out` marks the slot where a hit is INJECTED, but the
// digitized sample only reflects it after the shaper pipeline. LATENCIA shifts
// the anchor flag to the ADC time base. It is a PARAMETER and not a constant
// because it depends on which shaper is built (legacy or F34) — sweep it and
// measure, do not guess. Wrong alignment does not raise an error: it silently
// feeds the estimator samples that still carry pulse, biasing the baseline.

module gerador_ancora
#(
	parameter integer K_VAZIO  = 13,   // empty slots required before a sample counts
	parameter integer LATENCIA = 2     // shaper pipeline delay, in samples
)
(
	input  wire clk,
	input  wire rst,
	input  wire bt_mask,               // 1 = filled slot (from bunch_train_mask)
	output wire ancora
);

	localparam integer WC = $clog2(K_VAZIO + 2);

	reg [WC-1:0] cont = 0;             // consecutive empty slots
	reg          anc_r = 0;

	always @(posedge clk) begin
		if (rst) begin
			cont  <= 0;
			anc_r <= 0;
		end else if (bt_mask) begin
			cont  <= 0;
			anc_r <= 1'b0;
		end else begin
			if (cont <= K_VAZIO) cont <= cont + 1'b1;
			anc_r <= (cont + 1'b1 >= K_VAZIO);
		end
	end

	// LATENCIA = 0 uses anc_r directly (it already carries one register stage).
	// ⚠️ LATENCIA = 1 needs its own branch: the shift-register form would ask
	// for tubo[-1:0], which is a reversed part select and an elaboration error.
	generate
		if (LATENCIA == 0) begin : sem_atraso
			assign ancora = anc_r;
		end else if (LATENCIA == 1) begin : um_estagio
			reg tubo1 = 0;
			always @(posedge clk) begin
				if (rst) tubo1 <= 1'b0;
				else     tubo1 <= anc_r;
			end
			assign ancora = tubo1;
		end else begin : com_atraso
			reg [LATENCIA-1:0] tubo = 0;
			always @(posedge clk) begin
				if (rst) tubo <= 0;
				else     tubo <= {tubo[LATENCIA-2:0], anc_r};
			end
			assign ancora = tubo[LATENCIA-1];
		end
	endgenerate

endmodule
