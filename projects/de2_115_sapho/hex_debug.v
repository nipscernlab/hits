// hex_debug.v -- what reached hits, on the eight 7-segment displays of the DE2-115
// (issue #14), so the board can be checked with no PC.
//
// The registers of the bus are write-only, and the screen shows the copy the program
// keeps, not what hits got. This block watches the bus at the ports of hits and keeps
// the last word written to each register, and it counts the hits that come out of
// hits. The slide switches choose what the displays show, in decimal:
//
//   SW17 = 0: register SW[3:0] (2 to 8), as   "r  -12345": HEX7 the address, HEX5 the
//             sign, HEX4..HEX0 the value. PEDESTAL (4) and PHASE0 (7) are signed, the
//             others unsigned; any other address shows dashes.
//   SW17 = 1: hits per second (hits_out over GATE cycles of clk, 1 s at 40 MHz), on all
//             eight digits, updated once a second.
//
// Leading zeros are blank. The displays are common anode: a segment lights at 0.
module hex_debug #(
    parameter integer GATE = 40000000      // cycles of clk counted for the rate
) (
    input  wire        clk,
    input  wire        rst,
    // the bus of hits, as hits sees it
    input  wire [3:0]  addr,
    input  wire [15:0] wdata,
    input  wire        wr,
    input  wire        hits_out,
    input  wire [3:0]  sel,                 // SW[3:0]
    input  wire        rate_mode,           // SW17
    output wire [6:0]  hex0, hex1, hex2, hex3, hex4, hex5, hex6, hex7
);
    // ------------------------------------------------------------ the registers written
    reg [15:0] r2, r3, r4, r5, r6, r7, r8;
    always @(posedge clk)
        if (rst) begin
            r2 <= 0; r3 <= 0; r4 <= 0; r5 <= 0; r6 <= 0; r7 <= 0; r8 <= 0;
        end else if (wr)
            case (addr)
                4'd2: r2 <= wdata;
                4'd3: r3 <= wdata;
                4'd4: r4 <= wdata;
                4'd5: r5 <= wdata;
                4'd6: r6 <= wdata;
                4'd7: r7 <= wdata;
                4'd8: r8 <= wdata;
                default: ;
            endcase

    reg [15:0] v;
    reg        valid, is_signed;
    always @* begin
        valid = 1; is_signed = 0;
        case (sel)
            4'd2: v = r2;
            4'd3: v = r3;
            4'd4: begin v = r4; is_signed = 1; end
            4'd5: v = r5;
            4'd6: v = r6;
            4'd7: begin v = r7; is_signed = 1; end
            4'd8: v = r8;
            default: begin v = 0; valid = 0; end
        endcase
    end
    wire        neg = is_signed & v[15];
    wire [15:0] mag = neg ? -v : v;

    // binary to decimal by double dabble, one bit per cycle: a new value every 17 cycles
    reg [15:0] bin;
    reg [19:0] bcd, dec;
    reg        dec_neg, dec_valid;
    reg [4:0]  n;
    reg        neg_l, valid_l;

    function [19:0] add3; input [19:0] b; integer k; begin
        add3 = b;
        for (k = 0; k < 5; k = k + 1)
            if (add3[4*k +: 4] >= 5) add3[4*k +: 4] = add3[4*k +: 4] + 4'd3;
    end endfunction

    wire [35:0] shifted = {add3(bcd), bin} << 1;
    always @(posedge clk)
        if (rst) begin
            n <= 0; bin <= 0; bcd <= 0; dec <= 0; dec_neg <= 0; dec_valid <= 0;
            neg_l <= 0; valid_l <= 0;
        end else if (n == 0) begin
            bin <= mag; bcd <= 0; neg_l <= neg; valid_l <= valid; n <= 16;
        end else begin
            {bcd, bin} <= shifted;
            n <= n - 1'b1;
            if (n == 1) begin
                dec <= shifted[35:16]; dec_neg <= neg_l; dec_valid <= valid_l;
            end
        end

    // ------------------------------------------------------------ hits per second, in BCD
    function [31:0] bcd_inc; input [31:0] b; integer k; reg c; begin
        bcd_inc = b; c = 1;
        for (k = 0; k < 8; k = k + 1)
            if (c) begin
                if (bcd_inc[4*k +: 4] == 4'd9) bcd_inc[4*k +: 4] = 4'd0;
                else begin bcd_inc[4*k +: 4] = bcd_inc[4*k +: 4] + 4'd1; c = 0; end
            end
    end endfunction

    reg [25:0] gate;
    reg [31:0] count, rate;
    always @(posedge clk)
        if (rst) begin
            gate <= 0; count <= 0; rate <= 0;
        end else if (gate == GATE - 1) begin
            gate <= 0;
            rate <= hits_out ? bcd_inc(count) : count;
            count <= 0;
        end else begin
            gate <= gate + 1'b1;
            if (hits_out) count <= bcd_inc(count);
        end

    // ------------------------------------------------------------ the digits
    localparam [4:0] BLANK = 5'd16, MINUS = 5'd17;

    function [6:0] seg; input [4:0] d; begin       // bit k = segment k, 0 = lit
        case (d)
            5'd0: seg = 7'h40;  5'd1: seg = 7'h79;  5'd2: seg = 7'h24;  5'd3: seg = 7'h30;
            5'd4: seg = 7'h19;  5'd5: seg = 7'h12;  5'd6: seg = 7'h02;  5'd7: seg = 7'h78;
            5'd8: seg = 7'h00;  5'd9: seg = 7'h10;  5'd10: seg = 7'h08; 5'd11: seg = 7'h03;
            5'd12: seg = 7'h46; 5'd13: seg = 7'h21; 5'd14: seg = 7'h06; 5'd15: seg = 7'h0E;
            MINUS: seg = 7'h3F;
            default: seg = 7'h7F;
        endcase
    end endfunction

    // digits 0..7 (0 = HEX0), leading zeros of a number blank, digit 0 always shown
    reg [4:0] d [0:7];
    reg       lead;
    integer   k;
    always @* begin
        if (rate_mode) begin
            lead = 1;
            for (k = 7; k >= 0; k = k - 1) begin
                if (rate[4*k +: 4] != 0 || k == 0) lead = 0;
                d[k] = lead ? BLANK : {1'b0, rate[4*k +: 4]};
            end
        end else begin
            d[7] = {1'b0, sel};
            d[6] = BLANK;
            d[5] = dec_neg ? MINUS : BLANK;
            lead = 1;
            for (k = 4; k >= 0; k = k - 1) begin
                if (dec[4*k +: 4] != 0 || k == 0) lead = 0;
                d[k] = !dec_valid ? MINUS : lead ? BLANK : {1'b0, dec[4*k +: 4]};
            end
        end
    end

    assign hex0 = seg(d[0]); assign hex1 = seg(d[1]); assign hex2 = seg(d[2]); assign hex3 = seg(d[3]);
    assign hex4 = seg(d[4]); assign hex5 = seg(d[5]); assign hex6 = seg(d[6]); assign hex7 = seg(d[7]);
endmodule
