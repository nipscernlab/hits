`timescale 1ns/100ps

// Pole-zero cancellation (PZC) with pedestal tracking.
//
// Restores the baseline of the AC-coupled shaper output: cancels the AC pole
// (time constant = M_FACTOR clock periods) with an integrator, tracks the
// pedestal in +/-1 ADC steps, and applies gated corrections to the
// accumulator during long gaps of the bunch train (detected when the mask
// stays low for BT_NUM samples).
module pzc_ped_track
#(
	parameter NBITS_IN  = 12,          // input data width
	parameter NBITS_OUT = 28,          // output data width
	parameter M_FACTOR  = 454,         // PZC M factor (AC pole, in clock periods)
	parameter K_CORR = 2**4,           // negative samples before an accumulator correction
	parameter PED_CORR = 13,           // samples in the pedestal-drift window
	parameter BT_NUM = 16              // low-mask samples that define a long gap
)
(
	input                             clk, rst,
	input                             bt_mask_out,   // bunch-train mask (0 = gap)
	input   signed    [NBITS_IN -1:0] in,
	output reg signed [NBITS_IN -1:0] pedestal = 0,
	output signed     [NBITS_OUT-1:0] io_out
);

// thresholds of the gated corrections (values inherited from the original design)
localparam integer DIVERGE_THRESH = 1000;         // io_out jump that flags divergence
localparam integer DRIFT_THRESH   = PED_CORR*5;   // io_out drift that steps the pedestal

reg enable_acc_corr = 1'd1;
reg enable_ped = 1'd1;
reg enable_diverge = 1'd1;

reg signed [NBITS_OUT -1:0] out_delay = 0;

reg [20:0] cont1 = 0;                  // negative-sample counter
reg [20:0] cont2 = 0;                  // pedestal-window sample counter
reg [20:0] cont_bt = 0;                // samples with the mask low

reg signed [NBITS_OUT+K_CORR - 1:0] soma = 0;    // sum of negative samples
reg signed [NBITS_OUT+PED_CORR- 1:0] soma2 = 0;  // sum over the pedestal window
reg signed [NBITS_OUT -1:0] m_out = 0;           // accumulator correction
reg signed [NBITS_OUT -1:0] ped_reg_out = 0;
reg signed [NBITS_OUT -1:0] ped_reg_out_corr = 0;
reg signed [NBITS_OUT -1:0] io_out_delay = 0;
reg signed [NBITS_OUT -1:0] first_sample = 0;
reg signed [NBITS_OUT+6 -1:0] diff_last = 0;

always @(posedge clk or posedge rst)
begin
	if(rst) begin
		out_delay <= 0;
		cont1 <= 0;
		cont2 <= 0;
		cont_bt <= 0;
		pedestal <= 0;
		ped_reg_out <= 0;
		ped_reg_out_corr <= 0;
		enable_acc_corr <= 1'd1;
		io_out_delay <= 0;
		soma2 <= 0;
		enable_ped <= 1;
		first_sample <= 0;
		diff_last <= 0;
		enable_diverge <= 1'd1;
	end
	else
	begin
		out_delay <= (in-pedestal) + out_delay - m_out - ped_reg_out_corr;

		if (bt_mask_out == 0) begin         // inside a gap
			cont_bt <= cont_bt + 1'd1;
		end
		else begin
			cont_bt <= 0;
		end


		if(cont_bt >= BT_NUM) begin         // long gap: gated corrections active
			if(cont_bt == BT_NUM + K_CORR + 6) begin
				io_out_delay <= io_out;

				if (enable_diverge && (io_out - io_out_delay) > DIVERGE_THRESH) begin
					ped_reg_out <= in + out_delay - m_out;
					out_delay <= -(in-pedestal)*M_FACTOR;
					enable_diverge <= 1'd0;
				end
				else begin
					ped_reg_out <= 0;
					enable_diverge <= 1'd1;
				end

			end


			if(cont2 == 0) begin
				first_sample <= io_out;
			end


			if (io_out < 0) begin
				cont1 <= cont1 + 1'd1;
				soma <= soma + io_out;
			end

			if (enable_ped) begin
				cont2 <= cont2 + 1'd1;
				soma2 <= soma2 + io_out;
			end
			else begin
				soma2 <= 0;
				cont2 <= 0;
			end


			if (enable_acc_corr) begin
				if (cont1 == K_CORR) begin              // enough negative samples:
					m_out <= soma >>> $clog2(K_CORR);    // correct the accumulator
					cont1 <= 0;
					soma <= 0;
					enable_ped <= 0;
					enable_diverge <= 0;
				end
				else begin
					m_out <= 0;
					enable_diverge <= 1'd1;
				end
			end
			else begin
				m_out <= 0;
			end

			if (cont2 == PED_CORR) begin
				diff_last <= io_out - first_sample;
			end
			else begin
				diff_last <= 0;
			end

			if (diff_last > DRIFT_THRESH && soma2 > 0) begin
				enable_acc_corr <= 0;
				enable_ped <= 0;
				pedestal <= pedestal + 1'd1;
				diff_last <= 0;
				first_sample <= 0;
				ped_reg_out_corr <= soma2 >>> $clog2(K_CORR);
				enable_diverge <= 0;
			end
			else begin

				if (diff_last < -DRIFT_THRESH && soma2 < 0) begin
					enable_acc_corr <= 0;
					enable_ped <= 0;
					pedestal <= pedestal - 1'd1;
					diff_last <= 0;
					first_sample <= 0;
					ped_reg_out_corr <= soma2 >>> $clog2(K_CORR);
					enable_diverge <= 0;
				end
				else begin
					ped_reg_out_corr <= 0;
					enable_diverge <= 1'd1;
				end

			end

		end
		else begin                          // outside a long gap: idle state
			cont1 <= 0;
			cont2 <= 0;
			soma <= 0;
			m_out <= 0;
			ped_reg_out <= 0;
			enable_acc_corr <= 1'd1;
			ped_reg_out_corr <= 0;
			soma2 <= 0;
			enable_ped <= 1'd1;
			first_sample <= 0;
			diff_last <= 0;
			enable_diverge <= 1'd1;
		end

	end
end


assign io_out = (in - pedestal) + out_delay + M_FACTOR * (in - pedestal);  // PZC output


endmodule
