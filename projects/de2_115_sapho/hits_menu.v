module hits_menu (

input  clk, rst,
input  signed [15:0] in ,
output signed [15:0] out,
output [2:0] req_in,
output [8:0] out_en,
output cade_0,
input  taqui_0,
input  signed [15:0] cade_dado_0,
output toma_1,
input  valeu_1,
output signed [15:0] toma_dado);

/* verilator tracing_off */

wire itr = 1'b0;
wire cheguei;
wire [1:0] lk_toma, lk_cade, lk_valeu, lk_taqui;
wire [31:0] lk_cade_dado;
wire [15:0] lk_toma_dado;
assign lk_valeu[0] = 1'b0;
assign cade_0 = lk_cade[0];
assign lk_taqui[0] = taqui_0;
assign lk_cade_dado[15:0] = cade_dado_0;
assign toma_1 = lk_toma[1];
assign lk_valeu[1] = valeu_1;
assign lk_taqui[1] = 1'b0;
assign lk_cade_dado[31:16] = 0;
assign toma_dado = lk_toma_dado;
wire proc_req_in, proc_out_en;
wire [1:0] addr_in;
wire [3:0] addr_out;

`ifdef __ICARUS__
 `ifndef YANC_SIM_VIS
  `define YANC_SIM_VIS
 `endif
`endif
`ifdef YANC_TRACE
 `ifndef YANC_SIM_VIS
  `define YANC_SIM_VIS
 `endif
`endif

`ifdef YANC_SIM_VIS
wire mem_wr;
wire [9:0] mem_addr_wr;
wire [10:0] pc_sim_val;
`endif

processor#(.NUBITS(16),
.NBMANT(10),
.NBEXPO(5),
.NBOPER(11),
.NUGAIN(1),
.MDATAS(597),
.MINSTS(1152),
.SDEPTH(8),
.DDEPTH(8),
.NBIOIN(2),
.NBIOOU(4),
.FFTSIZ(3),
.FROUND(2),
.NLINK(2),
.TOMS(2'b10),
.CADS(2'b01),
.LSYNC(2'b00),
.POP(1),
.SET(1),
.TOM(1),
.CAD(1),
.LOD(1),
.LDI(1),
.JIZ(1),
.PSH(1),
.CAL(1),
.ADD(1),
.SET_P(1),
.INV(1),
.P_LOD(1),
.S_SHR(1),
.LES(1),
.NEG(1),
.S_ADD(1),
.EQU(1),
.AND(1),
.GRE(1),
.STI(1),
.LIN(1),
.S_EQU(1),
.P_NEG_M(1),
.S_LES(1),
.S_GRE(1),
.S_SHL(1),
.LIN_M(1),
.OUT(1),
.XOR(1),
.INN(1),
.P_INN(1),
.DFILE("hits_menu_data.mif"),
.IFILE("hits_menu_inst.mif"))

`ifdef YANC_SIM_VIS
p_hits_menu (clk, rst, in, out, addr_in, addr_out, proc_req_in, proc_out_en, itr, cheguei, lk_toma, lk_cade, lk_valeu, lk_taqui, lk_cade_dado, lk_toma_dado, mem_wr, mem_addr_wr,pc_sim_val);
`else
p_hits_menu (clk, rst, in, out, addr_in, addr_out, proc_req_in, proc_out_en, itr, cheguei, lk_toma, lk_cade, lk_valeu, lk_taqui, lk_cade_dado, lk_toma_dado);
`endif

addr_dec #(3) dec_in (proc_req_in, addr_in , req_in);
addr_dec #(9) dec_out(proc_out_en, addr_out, out_en);

/* verilator tracing_on */

// ----------------------------------------------------------------------------
// Simulation -----------------------------------------------------------------
// ----------------------------------------------------------------------------

`ifdef YANC_SIM_VIS

// I/O ------------------------------------------------------------------------

reg signed [15:0] in_sim_0 = 0;
reg req_in_sim_0 = 0;
reg signed [15:0] in_sim_1 = 0;
reg req_in_sim_1 = 0;
reg signed [15:0] in_sim_2 = 0;
reg req_in_sim_2 = 0;

reg signed [15:0] out_sig_2 = 0;
reg out_en_sim_2 = 0;
reg signed [15:0] out_sig_3 = 0;
reg out_en_sim_3 = 0;
reg signed [15:0] out_sig_4 = 0;
reg out_en_sim_4 = 0;
reg signed [15:0] out_sig_5 = 0;
reg out_en_sim_5 = 0;
reg signed [15:0] out_sig_6 = 0;
reg out_en_sim_6 = 0;
reg signed [15:0] out_sig_7 = 0;
reg out_en_sim_7 = 0;
reg signed [15:0] out_sig_8 = 0;
reg out_en_sim_8 = 0;

always @ (posedge clk) begin
   if (req_in[0]) in_sim_0 <= in;
   if (req_in[1]) in_sim_1 <= in;
   if (req_in[2]) in_sim_2 <= in;
end
always @ (*) begin
   req_in_sim_0 = req_in[0];
   req_in_sim_1 = req_in[1];
   req_in_sim_2 = req_in[2];
end

always @ (posedge clk) begin
   if (out_en[2]) out_sig_2 <= out;
   if (out_en[3]) out_sig_3 <= out;
   if (out_en[4]) out_sig_4 <= out;
   if (out_en[5]) out_sig_5 <= out;
   if (out_en[6]) out_sig_6 <= out;
   if (out_en[7]) out_sig_7 <= out;
   if (out_en[8]) out_sig_8 <= out;
end
always @ (*) begin
   out_en_sim_2 = out_en[2];
   out_en_sim_3 = out_en[3];
   out_en_sim_4 = out_en[4];
   out_en_sim_5 = out_en[5];
   out_en_sim_6 = out_en[6];
   out_en_sim_7 = out_en[7];
   out_en_sim_8 = out_en[8];
end

// variables ------------------------------------------------------------------

reg [15:0] me1_f_yanc_put_v_c_e_ = 0;
reg [15:0] me1_f_yanc_word_bits_v_x_e_ = 0;
reg [15:0] me1_f_yanc_word_bits_v_n_e_ = 0;
reg [15:0] me1_f_yanc_pad_v_fill_e_ = 0;
reg [15:0] me1_f_yanc_pad_v_n_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_plus_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_neg_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_upper_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_fill_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_width_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_base_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_v_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_n_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_sign_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_nb_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_b_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_c_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_i_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_t_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_sh_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_m_e_ = 0;
reg [15:0] me1_f_yanc_put_uint_v_x_e_ = 0;
reg [15:0] me1_f_yanc_put_int_v_plus_e_ = 0;
reg [15:0] me1_f_yanc_put_int_v_fill_e_ = 0;
reg [15:0] me1_f_yanc_put_int_v_width_e_ = 0;
reg [15:0] me1_f_yanc_put_int_v_v_e_ = 0;
reg [15:0] me1_f_global_v_yanc_line_len_e_ = 0;
reg [15:0] me1_f_global_v_yanc_line_pos_e_ = 0;
reg [15:0] me1_f_yanc_read_line_v_c_e_ = 0;
reg [15:0] me1_f_yanc_get_v_c_e_ = 0;
reg [15:0] me1_f_yanc_blank_v_c_e_ = 0;
reg [15:0] me1_f_yanc_get_int_v_neg_e_ = 0;
reg [15:0] me1_f_yanc_get_int_v_v_e_ = 0;
reg [15:0] me1_f_yanc_get_int_v_n_e_ = 0;
reg [15:0] me1_f_yanc_get_int_v_c_e_ = 0;
reg [15:0] me1_f_ostream__op_shl_Opi_v_v_e_ = 0;
reg [15:0] me1_f_ostream__op_shl_Opu_v_v_e_ = 0;
reg [15:0] me1_f_istream__op_shr_OpI_v_ok_e_ = 0;
reg [15:0] me1_f_istream__op_shr_OpI_v_x_e_ = 0;
reg [15:0] me1_f_istream__op_shr_OpU_v_ok_e_ = 0;
reg [15:0] me1_f_istream__op_shr_OpU_v_x_e_ = 0;
reg [15:0] me1_f_istream__ignore_v_delim_e_ = 0;
reg [15:0] me1_f_istream__ignore_v_n_e_ = 0;
reg [15:0] me1_f_istream__ignore_v_i_e_ = 0;
reg [15:0] me1_f_global_v_occupancy_e_ = 0;
reg [15:0] me1_f_global_v_pedestal_e_ = 0;
reg [15:0] me1_f_global_v_mode_e_ = 0;
reg [15:0] me1_f_global_v_orbit_e_ = 0;
reg [15:0] me1_f_global_v_phase0_e_ = 0;
reg [15:0] me1_f_global_v_sigma_e_ = 0;
reg [15:0] me1_f_read_int_v_hi_e_ = 0;
reg [15:0] me1_f_read_int_v_lo_e_ = 0;
reg [15:0] me1_f_read_int_v_v_e_ = 0;
reg [15:0] me1_f_read_uint_v_hi_e_ = 0;
reg [15:0] me1_f_read_uint_v_v_e_ = 0;
reg [15:0] me1_f_read_uint_v_ok_e_ = 0;
reg [15:0] me1_f_show_v_caps_e_ = 0;
reg [15:0] me1_f_global_v_ORBIT_MAX_e_ = 0;
reg [15:0] me1_f_main_v_op_e_ = 0;
reg [15:0] me1_f_main_v_running_e_ = 0;

always @ (posedge clk) begin
   if (mem_wr && (pc_sim_val == 4)) me1_f_yanc_put_v_c_e_ <= out;
   if (mem_wr && (pc_sim_val == 26 || pc_sim_val == 34)) me1_f_yanc_word_bits_v_x_e_ <= out;
   if (mem_wr && (pc_sim_val == 28 || pc_sim_val == 37)) me1_f_yanc_word_bits_v_n_e_ <= out;
   if (mem_addr_wr == 416 && mem_wr) me1_f_yanc_pad_v_fill_e_ <= out;
   if (mem_addr_wr == 417 && mem_wr) me1_f_yanc_pad_v_n_e_ <= out;
   if (mem_wr && (pc_sim_val == 58)) me1_f_yanc_put_uint_v_plus_e_ <= out;
   if (mem_wr && (pc_sim_val == 59)) me1_f_yanc_put_uint_v_neg_e_ <= out;
   if (mem_wr && (pc_sim_val == 60)) me1_f_yanc_put_uint_v_upper_e_ <= out;
   if (mem_wr && (pc_sim_val == 61)) me1_f_yanc_put_uint_v_fill_e_ <= out;
   if (mem_addr_wr == 422 && mem_wr) me1_f_yanc_put_uint_v_width_e_ <= out;
   if (mem_wr && (pc_sim_val == 63)) me1_f_yanc_put_uint_v_base_e_ <= out;
   if (mem_addr_wr == 423 && mem_wr) me1_f_yanc_put_uint_v_v_e_ <= out;
   if (mem_addr_wr == 464 && mem_wr) me1_f_yanc_put_uint_v_n_e_ <= out;
   if (mem_wr && (pc_sim_val == 176)) me1_f_yanc_put_uint_v_sign_e_ <= out;
   if (mem_wr && (pc_sim_val == 71)) me1_f_yanc_put_uint_v_nb_e_ <= out;
   if (mem_wr && (pc_sim_val == 80 || pc_sim_val == 132)) me1_f_yanc_put_uint_v_b_e_ <= out;
   if (mem_wr && (pc_sim_val == 87 || pc_sim_val == 107 || pc_sim_val == 110)) me1_f_yanc_put_uint_v_c_e_ <= out;
   if (mem_wr && (pc_sim_val == 89 || pc_sim_val == 116)) me1_f_yanc_put_uint_v_i_e_ <= out;
   if (mem_addr_wr == 468 && mem_wr) me1_f_yanc_put_uint_v_t_e_ <= out;
   if (mem_wr && (pc_sim_val == 147)) me1_f_yanc_put_uint_v_sh_e_ <= out;
   if (mem_wr && (pc_sim_val == 152)) me1_f_yanc_put_uint_v_m_e_ <= out;
   if (mem_wr && (pc_sim_val == 222)) me1_f_yanc_put_uint_v_x_e_ <= out;
   if (mem_wr && (pc_sim_val == 242)) me1_f_yanc_put_int_v_plus_e_ <= out;
   if (mem_wr && (pc_sim_val == 243)) me1_f_yanc_put_int_v_fill_e_ <= out;
   if (mem_wr && (pc_sim_val == 244)) me1_f_yanc_put_int_v_width_e_ <= out;
   if (mem_wr && (pc_sim_val == 245)) me1_f_yanc_put_int_v_v_e_ <= out;
   if (mem_addr_wr == 479 && mem_wr) me1_f_global_v_yanc_line_len_e_ <= out;
   if (mem_addr_wr == 480 && mem_wr) me1_f_global_v_yanc_line_pos_e_ <= out;
   if (mem_wr && (pc_sim_val == 277 || pc_sim_val == 310)) me1_f_yanc_read_line_v_c_e_ <= out;
   if (mem_wr && (pc_sim_val == 343)) me1_f_yanc_get_v_c_e_ <= out;
   if (mem_wr && (pc_sim_val == 350)) me1_f_yanc_blank_v_c_e_ <= out;
   if (mem_addr_wr == 486 && mem_wr) me1_f_yanc_get_int_v_neg_e_ <= out;
   if (mem_addr_wr == 487 && mem_wr) me1_f_yanc_get_int_v_v_e_ <= out;
   if (mem_addr_wr == 488 && mem_wr) me1_f_yanc_get_int_v_n_e_ <= out;
   if (mem_wr && (pc_sim_val == 391 || pc_sim_val == 410)) me1_f_yanc_get_int_v_c_e_ <= out;
   if (mem_wr && (pc_sim_val == 461)) me1_f_ostream__op_shl_Opi_v_v_e_ <= out;
   if (mem_wr && (pc_sim_val == 491)) me1_f_ostream__op_shl_Opu_v_v_e_ <= out;
   if (mem_addr_wr == 497 && mem_wr) me1_f_istream__op_shr_OpI_v_ok_e_ <= out;
   if (mem_wr && (pc_sim_val == 541)) me1_f_istream__op_shr_OpI_v_x_e_ <= out;
   if (mem_addr_wr == 501 && mem_wr) me1_f_istream__op_shr_OpU_v_ok_e_ <= out;
   if (mem_wr && (pc_sim_val == 564)) me1_f_istream__op_shr_OpU_v_x_e_ <= out;
   if (mem_addr_wr == 503 && mem_wr) me1_f_istream__ignore_v_delim_e_ <= out;
   if (mem_addr_wr == 504 && mem_wr) me1_f_istream__ignore_v_n_e_ <= out;
   if (mem_addr_wr == 506 && mem_wr) me1_f_istream__ignore_v_i_e_ <= out;
   if (mem_wr && (pc_sim_val == 1009 || pc_sim_val == 1082)) me1_f_global_v_occupancy_e_ <= out;
   if (mem_addr_wr == 508 && mem_wr) me1_f_global_v_pedestal_e_ <= out;
   if (mem_addr_wr == 509 && mem_wr) me1_f_global_v_mode_e_ <= out;
   if (mem_addr_wr == 510 && mem_wr) me1_f_global_v_orbit_e_ <= out;
   if (mem_addr_wr == 511 && mem_wr) me1_f_global_v_phase0_e_ <= out;
   if (mem_addr_wr == 512 && mem_wr) me1_f_global_v_sigma_e_ <= out;
   if (mem_addr_wr == 513 && mem_wr) me1_f_read_int_v_hi_e_ <= out;
   if (mem_addr_wr == 514 && mem_wr) me1_f_read_int_v_lo_e_ <= out;
   if (mem_addr_wr == 520 && mem_wr) me1_f_read_int_v_v_e_ <= out;
   if (mem_addr_wr == 527 && mem_wr) me1_f_read_uint_v_hi_e_ <= out;
   if (mem_addr_wr == 530 && mem_wr) me1_f_read_uint_v_v_e_ <= out;
   if (mem_addr_wr == 532 && mem_wr) me1_f_read_uint_v_ok_e_ <= out;
   if (mem_wr && (pc_sim_val == 760)) me1_f_show_v_caps_e_ <= out;
   if (mem_wr && (pc_sim_val == 1007)) me1_f_global_v_ORBIT_MAX_e_ <= out;
   if (mem_addr_wr == 585 && mem_wr) me1_f_main_v_op_e_ <= out;
   if (mem_wr && (pc_sim_val == 1106 || pc_sim_val == 1129)) me1_f_main_v_running_e_ <= out;
end

// arrays ---------------------------------------------------------------------

reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0000=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0001=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0002=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0003=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0004=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0005=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0006=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0007=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0008=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0009=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0010=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0011=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0012=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0013=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0014=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0015=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0016=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0017=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0018=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0019=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0020=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0021=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0022=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0023=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0024=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0025=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0026=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0027=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0028=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0029=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0030=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0031=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0032=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0033=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0034=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0035=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0036=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0037=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0038=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0039=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0040=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0041=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0042=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0043=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0044=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0045=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0046=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0047=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0048=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0049=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0050=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0051=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0052=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0053=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0054=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0055=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0056=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0057=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0058=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0059=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0060=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0061=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0062=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0063=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0064=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0065=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0066=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0067=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0068=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0069=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0070=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0071=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0072=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0073=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0074=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0075=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0076=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0077=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0078=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0079=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0080=16'b0000000000000000;
reg [16-1:0] arr_me1_f_global_v_yanc_line_e_0081=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0000=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0001=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0002=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0003=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0004=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0005=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0006=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0007=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0008=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0009=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0010=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0011=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0012=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0013=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0014=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0015=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0016=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0017=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0018=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0019=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0020=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0021=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0022=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0023=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0024=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0025=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0026=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0027=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0028=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0029=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0030=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0031=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0032=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0033=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0034=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0035=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0036=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0037=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0038=16'b0000000000000000;
reg [16-1:0] arr_me1_f_yanc_put_uint_v_d_e_0039=16'b0000000000000000;

always @ (posedge clk) begin
   if (mem_addr_wr == 0 && mem_wr) arr_me1_f_global_v_yanc_line_e_0000 <= out;
   if (mem_addr_wr == 1 && mem_wr) arr_me1_f_global_v_yanc_line_e_0001 <= out;
   if (mem_addr_wr == 2 && mem_wr) arr_me1_f_global_v_yanc_line_e_0002 <= out;
   if (mem_addr_wr == 3 && mem_wr) arr_me1_f_global_v_yanc_line_e_0003 <= out;
   if (mem_addr_wr == 4 && mem_wr) arr_me1_f_global_v_yanc_line_e_0004 <= out;
   if (mem_addr_wr == 5 && mem_wr) arr_me1_f_global_v_yanc_line_e_0005 <= out;
   if (mem_addr_wr == 6 && mem_wr) arr_me1_f_global_v_yanc_line_e_0006 <= out;
   if (mem_addr_wr == 7 && mem_wr) arr_me1_f_global_v_yanc_line_e_0007 <= out;
   if (mem_addr_wr == 8 && mem_wr) arr_me1_f_global_v_yanc_line_e_0008 <= out;
   if (mem_addr_wr == 9 && mem_wr) arr_me1_f_global_v_yanc_line_e_0009 <= out;
   if (mem_addr_wr == 10 && mem_wr) arr_me1_f_global_v_yanc_line_e_0010 <= out;
   if (mem_addr_wr == 11 && mem_wr) arr_me1_f_global_v_yanc_line_e_0011 <= out;
   if (mem_addr_wr == 12 && mem_wr) arr_me1_f_global_v_yanc_line_e_0012 <= out;
   if (mem_addr_wr == 13 && mem_wr) arr_me1_f_global_v_yanc_line_e_0013 <= out;
   if (mem_addr_wr == 14 && mem_wr) arr_me1_f_global_v_yanc_line_e_0014 <= out;
   if (mem_addr_wr == 15 && mem_wr) arr_me1_f_global_v_yanc_line_e_0015 <= out;
   if (mem_addr_wr == 16 && mem_wr) arr_me1_f_global_v_yanc_line_e_0016 <= out;
   if (mem_addr_wr == 17 && mem_wr) arr_me1_f_global_v_yanc_line_e_0017 <= out;
   if (mem_addr_wr == 18 && mem_wr) arr_me1_f_global_v_yanc_line_e_0018 <= out;
   if (mem_addr_wr == 19 && mem_wr) arr_me1_f_global_v_yanc_line_e_0019 <= out;
   if (mem_addr_wr == 20 && mem_wr) arr_me1_f_global_v_yanc_line_e_0020 <= out;
   if (mem_addr_wr == 21 && mem_wr) arr_me1_f_global_v_yanc_line_e_0021 <= out;
   if (mem_addr_wr == 22 && mem_wr) arr_me1_f_global_v_yanc_line_e_0022 <= out;
   if (mem_addr_wr == 23 && mem_wr) arr_me1_f_global_v_yanc_line_e_0023 <= out;
   if (mem_addr_wr == 24 && mem_wr) arr_me1_f_global_v_yanc_line_e_0024 <= out;
   if (mem_addr_wr == 25 && mem_wr) arr_me1_f_global_v_yanc_line_e_0025 <= out;
   if (mem_addr_wr == 26 && mem_wr) arr_me1_f_global_v_yanc_line_e_0026 <= out;
   if (mem_addr_wr == 27 && mem_wr) arr_me1_f_global_v_yanc_line_e_0027 <= out;
   if (mem_addr_wr == 28 && mem_wr) arr_me1_f_global_v_yanc_line_e_0028 <= out;
   if (mem_addr_wr == 29 && mem_wr) arr_me1_f_global_v_yanc_line_e_0029 <= out;
   if (mem_addr_wr == 30 && mem_wr) arr_me1_f_global_v_yanc_line_e_0030 <= out;
   if (mem_addr_wr == 31 && mem_wr) arr_me1_f_global_v_yanc_line_e_0031 <= out;
   if (mem_addr_wr == 32 && mem_wr) arr_me1_f_global_v_yanc_line_e_0032 <= out;
   if (mem_addr_wr == 33 && mem_wr) arr_me1_f_global_v_yanc_line_e_0033 <= out;
   if (mem_addr_wr == 34 && mem_wr) arr_me1_f_global_v_yanc_line_e_0034 <= out;
   if (mem_addr_wr == 35 && mem_wr) arr_me1_f_global_v_yanc_line_e_0035 <= out;
   if (mem_addr_wr == 36 && mem_wr) arr_me1_f_global_v_yanc_line_e_0036 <= out;
   if (mem_addr_wr == 37 && mem_wr) arr_me1_f_global_v_yanc_line_e_0037 <= out;
   if (mem_addr_wr == 38 && mem_wr) arr_me1_f_global_v_yanc_line_e_0038 <= out;
   if (mem_addr_wr == 39 && mem_wr) arr_me1_f_global_v_yanc_line_e_0039 <= out;
   if (mem_addr_wr == 40 && mem_wr) arr_me1_f_global_v_yanc_line_e_0040 <= out;
   if (mem_addr_wr == 41 && mem_wr) arr_me1_f_global_v_yanc_line_e_0041 <= out;
   if (mem_addr_wr == 42 && mem_wr) arr_me1_f_global_v_yanc_line_e_0042 <= out;
   if (mem_addr_wr == 43 && mem_wr) arr_me1_f_global_v_yanc_line_e_0043 <= out;
   if (mem_addr_wr == 44 && mem_wr) arr_me1_f_global_v_yanc_line_e_0044 <= out;
   if (mem_addr_wr == 45 && mem_wr) arr_me1_f_global_v_yanc_line_e_0045 <= out;
   if (mem_addr_wr == 46 && mem_wr) arr_me1_f_global_v_yanc_line_e_0046 <= out;
   if (mem_addr_wr == 47 && mem_wr) arr_me1_f_global_v_yanc_line_e_0047 <= out;
   if (mem_addr_wr == 48 && mem_wr) arr_me1_f_global_v_yanc_line_e_0048 <= out;
   if (mem_addr_wr == 49 && mem_wr) arr_me1_f_global_v_yanc_line_e_0049 <= out;
   if (mem_addr_wr == 50 && mem_wr) arr_me1_f_global_v_yanc_line_e_0050 <= out;
   if (mem_addr_wr == 51 && mem_wr) arr_me1_f_global_v_yanc_line_e_0051 <= out;
   if (mem_addr_wr == 52 && mem_wr) arr_me1_f_global_v_yanc_line_e_0052 <= out;
   if (mem_addr_wr == 53 && mem_wr) arr_me1_f_global_v_yanc_line_e_0053 <= out;
   if (mem_addr_wr == 54 && mem_wr) arr_me1_f_global_v_yanc_line_e_0054 <= out;
   if (mem_addr_wr == 55 && mem_wr) arr_me1_f_global_v_yanc_line_e_0055 <= out;
   if (mem_addr_wr == 56 && mem_wr) arr_me1_f_global_v_yanc_line_e_0056 <= out;
   if (mem_addr_wr == 57 && mem_wr) arr_me1_f_global_v_yanc_line_e_0057 <= out;
   if (mem_addr_wr == 58 && mem_wr) arr_me1_f_global_v_yanc_line_e_0058 <= out;
   if (mem_addr_wr == 59 && mem_wr) arr_me1_f_global_v_yanc_line_e_0059 <= out;
   if (mem_addr_wr == 60 && mem_wr) arr_me1_f_global_v_yanc_line_e_0060 <= out;
   if (mem_addr_wr == 61 && mem_wr) arr_me1_f_global_v_yanc_line_e_0061 <= out;
   if (mem_addr_wr == 62 && mem_wr) arr_me1_f_global_v_yanc_line_e_0062 <= out;
   if (mem_addr_wr == 63 && mem_wr) arr_me1_f_global_v_yanc_line_e_0063 <= out;
   if (mem_addr_wr == 64 && mem_wr) arr_me1_f_global_v_yanc_line_e_0064 <= out;
   if (mem_addr_wr == 65 && mem_wr) arr_me1_f_global_v_yanc_line_e_0065 <= out;
   if (mem_addr_wr == 66 && mem_wr) arr_me1_f_global_v_yanc_line_e_0066 <= out;
   if (mem_addr_wr == 67 && mem_wr) arr_me1_f_global_v_yanc_line_e_0067 <= out;
   if (mem_addr_wr == 68 && mem_wr) arr_me1_f_global_v_yanc_line_e_0068 <= out;
   if (mem_addr_wr == 69 && mem_wr) arr_me1_f_global_v_yanc_line_e_0069 <= out;
   if (mem_addr_wr == 70 && mem_wr) arr_me1_f_global_v_yanc_line_e_0070 <= out;
   if (mem_addr_wr == 71 && mem_wr) arr_me1_f_global_v_yanc_line_e_0071 <= out;
   if (mem_addr_wr == 72 && mem_wr) arr_me1_f_global_v_yanc_line_e_0072 <= out;
   if (mem_addr_wr == 73 && mem_wr) arr_me1_f_global_v_yanc_line_e_0073 <= out;
   if (mem_addr_wr == 74 && mem_wr) arr_me1_f_global_v_yanc_line_e_0074 <= out;
   if (mem_addr_wr == 75 && mem_wr) arr_me1_f_global_v_yanc_line_e_0075 <= out;
   if (mem_addr_wr == 76 && mem_wr) arr_me1_f_global_v_yanc_line_e_0076 <= out;
   if (mem_addr_wr == 77 && mem_wr) arr_me1_f_global_v_yanc_line_e_0077 <= out;
   if (mem_addr_wr == 78 && mem_wr) arr_me1_f_global_v_yanc_line_e_0078 <= out;
   if (mem_addr_wr == 79 && mem_wr) arr_me1_f_global_v_yanc_line_e_0079 <= out;
   if (mem_addr_wr == 80 && mem_wr) arr_me1_f_global_v_yanc_line_e_0080 <= out;
   if (mem_addr_wr == 81 && mem_wr) arr_me1_f_global_v_yanc_line_e_0081 <= out;
   if (mem_addr_wr == 424 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0000 <= out;
   if (mem_addr_wr == 425 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0001 <= out;
   if (mem_addr_wr == 426 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0002 <= out;
   if (mem_addr_wr == 427 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0003 <= out;
   if (mem_addr_wr == 428 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0004 <= out;
   if (mem_addr_wr == 429 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0005 <= out;
   if (mem_addr_wr == 430 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0006 <= out;
   if (mem_addr_wr == 431 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0007 <= out;
   if (mem_addr_wr == 432 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0008 <= out;
   if (mem_addr_wr == 433 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0009 <= out;
   if (mem_addr_wr == 434 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0010 <= out;
   if (mem_addr_wr == 435 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0011 <= out;
   if (mem_addr_wr == 436 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0012 <= out;
   if (mem_addr_wr == 437 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0013 <= out;
   if (mem_addr_wr == 438 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0014 <= out;
   if (mem_addr_wr == 439 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0015 <= out;
   if (mem_addr_wr == 440 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0016 <= out;
   if (mem_addr_wr == 441 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0017 <= out;
   if (mem_addr_wr == 442 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0018 <= out;
   if (mem_addr_wr == 443 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0019 <= out;
   if (mem_addr_wr == 444 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0020 <= out;
   if (mem_addr_wr == 445 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0021 <= out;
   if (mem_addr_wr == 446 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0022 <= out;
   if (mem_addr_wr == 447 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0023 <= out;
   if (mem_addr_wr == 448 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0024 <= out;
   if (mem_addr_wr == 449 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0025 <= out;
   if (mem_addr_wr == 450 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0026 <= out;
   if (mem_addr_wr == 451 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0027 <= out;
   if (mem_addr_wr == 452 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0028 <= out;
   if (mem_addr_wr == 453 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0029 <= out;
   if (mem_addr_wr == 454 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0030 <= out;
   if (mem_addr_wr == 455 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0031 <= out;
   if (mem_addr_wr == 456 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0032 <= out;
   if (mem_addr_wr == 457 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0033 <= out;
   if (mem_addr_wr == 458 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0034 <= out;
   if (mem_addr_wr == 459 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0035 <= out;
   if (mem_addr_wr == 460 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0036 <= out;
   if (mem_addr_wr == 461 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0037 <= out;
   if (mem_addr_wr == 462 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0038 <= out;
   if (mem_addr_wr == 463 && mem_wr) arr_me1_f_yanc_put_uint_v_d_e_0039 <= out;
end


// instructions ---------------------------------------------------------------

reg [15:0] valr2=0;
/* verilator tracing_off */
reg [15:0] valr1 /* verilator public_flat */=0;
reg [15:0] valr3 /* verilator public_flat */=0;
reg [15:0] valr4 /* verilator public_flat */=0;
reg [15:0] valr5 /* verilator public_flat */=0;
reg [15:0] valr6 /* verilator public_flat */=0;
reg [15:0] valr7 /* verilator public_flat */=0;
reg [15:0] valr8 /* verilator public_flat */=0;
reg [15:0] valr9 /* verilator public_flat */=0;
reg [15:0] valr10 /* verilator public_flat */=0;
/* verilator tracing_on */

reg [19:0] min [0:1152-1];

/* verilator tracing_off */ reg signed [19:0] linetab /* verilator public_flat */ =-1; /* verilator tracing_on */
reg signed [19:0] linetabs=-1;

initial	$readmemb("pc_hits_menu_mem.txt",min);

always @ (posedge clk) begin
if (pc_sim_val < 1152) linetab <= min[pc_sim_val];
linetabs <= linetab;   
valr1    <= {{(5){1'b0}}, pc_sim_val};
valr2    <= valr1;
valr3    <= valr2;
valr4    <= valr3;
valr5    <= valr4;
valr6    <= valr5;
valr7    <= valr6;
valr8    <= valr7;
valr9    <= valr8;
valr10   <= valr9;
end

`endif

endmodule