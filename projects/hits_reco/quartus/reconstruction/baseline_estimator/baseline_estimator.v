// F14: the COMPLETE baseline estimator (stage 2): level tracker + shape per BCID
// + interpolation by a slope accumulator.
//
//   at each ANCHOR i:  L    += (x - s[i] - L) >> K_LEVEL
//                      s[i] += ((x - L) - s[i]) >> K_SHAPE      // streaming
//   at each sample:    y     = x - round(L + interp(s))
//
// x is the DEVIATION from the pedestal, signed. `anchor` comes from the
// bunch-train mask (a slot empty for >= 13 BC), not from threshold detection.
//
// L AND s LIVE ON THE SAME FRACTIONAL GRID (FRAC bits): they add directly and
// there is ONE rounding at the end. Rounding the shape to whole ADC counts before
// adding throws the fraction away and costs part of the gain.
//
// THE INTERPOLATION HAS NO DIVIDER IN THE DATAPATH. Between anchor i and the
// next, N slots apart, the shape moves on a ramp:
//     at the anchor:  inc = (s[i+1] - s[i]) * recip[i] >> (R - FRAC_I)   // 1 product
//                     acc = s[i] << FRAC_I
//     elsewhere:      acc += inc
// `recip[i] = round(2^R / N)` comes from a ROM because the MASK IS STATIC: the N
// are known at design time. There is ONE product PER ANCHOR (654 per orbit, about
// 7.3 per microsecond), not one per slot, so one multiplier is enough.
// And 631 of the 654 gaps have N = 1 (inside a block of anchors the empty slots
// are consecutive); only the 23 gaps BETWEEN blocks are long (92 to 135).
//
// DEAD ZONE, the trap that applies to BOTH shifts: without fraction bits, `>> K`
// of anything below 2^K gives zero and the filter stops learning. At `>> K_SHAPE`
// (8) the increment is 16 times smaller than at `>> K_LEVEL` (4), so it is WORSE
// there: measured in F14, with FRAC = 0 the shape does not just stop helping, it
// makes the estimator WORSE (1.496 against 1.420 with no shape at all). No error
// is raised.

module baseline_estimator #(
    parameter integer BITS_IN   = 13,   // width of x, signed
    parameter integer FRAC      = 6,    // fraction of L and of s (the SAME grid)
    parameter integer FRAC_I    = 6,    // fraction of the interpolation accumulator
    parameter integer K_LEVEL   = 4,    // level memory: 2^K anchors
    parameter integer K_SHAPE   = 8,    // shape memory: 2^K orbits
    parameter integer N_ANCHORS = 654,  // anchors per orbit (from the mask)
    parameter integer R         = 16,   // bits of the reciprocal
    parameter integer WS        = 14,   // width of s[i] (654 x 14 = 9156 bits: fits 1 M10K block)
    parameter RECIP_MEM         = "recip.mem",
    // PRELOADED START: in real operation the shape and the level come from a
    // table (database, calibration run), not from zero. S_INIT_MEM = "" starts
    // from zero, and the shape takes about 2^K_SHAPE orbits (about 23 ms) to converge.
    parameter S_INIT_MEM        = "",
    parameter signed [31:0] L_INIT = 0,  // initial level, on the FRAC-bit grid
    // PHASE OF THE ANCHOR INDEX. `ia` counts anchors and addresses the reciprocal
    // ROM, which describes the gap TO THE NEXT anchor. If `ia` starts out of
    // phase, recip[ia] is the gap of ANOTHER anchor, and since 631 of the 654
    // gaps have N = 1, in the 23 LONG gaps the ramp runs off with the reciprocal
    // of a short gap. The error does not show at the anchors (they keep being
    // adjusted): it blows up BETWEEN them, with no warning at all.
    // Once in phase there is no drift: there are exactly N_ANCHORS anchors per orbit.
    // The value depends on where the orbit starts and on the pipeline: MEASURE it.
    parameter integer IA_INIT = 0
)(
    input  wire                      clk,
    input  wire                      rst,        // synchronous, active high
    input  wire                      valid,
    input  wire signed [BITS_IN-1:0] x,          // deviation from the pedestal
    input  wire                      anchor,
    output reg  signed [BITS_IN-1:0] y,          // x - correction
    output reg  signed [BITS_IN-1:0] correction  // the correction applied, for debugging
);

    // The ROM has R+1 BITS, not R: 631 of the 654 gaps have N = 1, and
    // round(2^R / 1) = 2^R, which does NOT fit in R bits. With R bits the value
    // truncates to zero and the interpolation dies in the short gaps, silently.
    localparam integer WR   = R + 1;               // width of the reciprocal
    localparam integer WL   = BITS_IN + FRAC;      // width of L
    localparam integer WA   = WS + FRAC_I + 2;     // width of the accumulator
    localparam integer WI   = WS + 1 + WR;         // width of the product
    localparam integer IAW  = $clog2(N_ANCHORS);
    localparam signed [WL:0] HALF = (FRAC > 0) ? (1 <<< (FRAC - 1)) : 0;

    // SYNCHRONOUS READ WITH PREFETCH, which is what maps the memory to M10K.
    //
    // The earlier version read `s_ram[ia]` and `s_ram[ia_next]` with `assign`,
    // that is ASYNCHRONOUSLY. The Cyclone V memory block requires a REGISTERED
    // READ ADDRESS, so synthesis put everything in logic: measured in Quartus,
    // 8285 ALMs + 9255 registers (= 654 x 14, the whole RAM became a bank of
    // flip-flops) and ZERO memory blocks. See F15.
    //
    // THE PREFETCH COMES FOR FREE because `ia` advances exactly 1 per anchor:
    // the `s[ia+1]` read at anchor k IS the `s[ia]` that anchor k+1 needs. It is
    // enough to load one register from the other:
    //     at anchor k:  s_a <= s_b            (s[i_k+1] becomes the s_cur of k+1)
    //                   read s_ram[i_k+2]  -> reaches s_b in time for k+1
    //                   read recip[i_k+1]  -> reaches rc  in time for k+1
    // The worst case is anchors on CONSECUTIVE cycles (631 of the 654 gaps have
    // N = 1), and even then the read arrives: it is issued one cycle earlier.
    //
    // AND THE ARITHMETIC IS IDENTICAL. Between anchor k-1 and k the only write
    // is to `s_ram[i_{k-1}]`, an address different from i_k and from i_k+1, so the
    // prefetched value is the one the asynchronous read would give. Checked bit for
    // bit against the model (F15): 0 differences in 400 orbits.
    // Only the START changes: `prime` spends one cycle after reset loading
    // s_a/s_b/rc. Since the first anchor comes >= 13 cycles later, there is no conflict.
    reg signed [WS-1:0]  s_ram [0:N_ANCHORS-1];
    reg        [WR-1:0]  recip [0:N_ANCHORS-1];

    reg signed [WS-1:0]  s_a, s_b;    // s[ia] and s[ia+1], prefetched
    reg        [WR-1:0]  rc;          // recip[ia], prefetched
    reg        [IAW-1:0] ra_s, ra_r;  // addresses held between anchors
    reg                  prime;

    reg signed [WL-1:0]  l_reg;
    reg signed [WA-1:0]  acc;
    reg signed [WA-1:0]  inc;
    reg        [IAW-1:0] ia;

    integer k;
    initial begin
        $readmemh(RECIP_MEM, recip);
        for (k = 0; k < N_ANCHORS; k = k + 1) s_ram[k] = {WS{1'b0}};
        if (S_INIT_MEM != "") $readmemh(S_INIT_MEM, s_ram);
    end

    wire [IAW-1:0] ia_next = (ia == N_ANCHORS-1) ? {IAW{1'b0}} : ia + 1'b1;
    wire [IAW-1:0] ia_p2   = (ia_next == N_ANCHORS-1) ? {IAW{1'b0}} : ia_next + 1'b1;

    wire step = valid & anchor;       // an anchor only counts if the sample is valid

    // addresses presented to the memory IN THIS cycle (the data arrives in the next)
    wire [IAW-1:0] a_s = rst ? IA_INIT[IAW-1:0] : (step ? ia_p2   : ra_s);
    wire [IAW-1:0] a_r = rst ? IA_INIT[IAW-1:0] : (step ? ia_next : ra_r);

    // the prefetched values take the place of the asynchronous read
    wire signed [WS:0] s_cur  = $signed({s_a[WS-1], s_a});
    wire signed [WS:0] s_next = $signed({s_b[WS-1], s_b});

    // x promoted to the fractional grid
    wire signed [WL:0] x_ext = $signed({{(FRAC+1){x[BITS_IN-1]}}, x}) <<< FRAC;
    wire signed [WL:0] l_ext = $signed({l_reg[WL-1], l_reg});

    // --- level: L += (x - s[i] - L) >> K_LEVEL   (only at an anchor)
    wire signed [WL:0] d_level = x_ext - s_cur - l_ext;
    wire signed [WL:0] l_next  = l_ext + (d_level >>> K_LEVEL);
    wire signed [WL:0] l_eff   = anchor ? l_next : l_ext;

    // --- shape: s[i] += ((x - L) - s[i]) >> K_SHAPE, with L ALREADY updated
    wire signed [WL:0] d_shape = (x_ext - l_next) - s_cur;
    wire signed [WL:0] s_new_w = s_cur + (d_shape >>> K_SHAPE);
    wire signed [WS-1:0] s_new = s_new_w[WS-1:0];

    // --- interpolation: reload at the anchor, accumulate elsewhere
    wire signed [WI-1:0] prod = ($signed(s_next) - $signed({s_new[WS-1], s_new}))
                                * $signed({1'b0, rc});          // 1 product per anchor
    wire signed [WA-1:0] inc_new = prod >>> (R - FRAC_I);
    wire signed [WA-1:0] acc_eff = anchor ? ($signed({s_new[WS-1], s_new}) <<< FRAC_I)
                                          : (acc + inc);

    // --- sum on the common grid and ONE rounding
    wire signed [WL:0] total = l_eff + $signed(acc_eff >>> FRAC_I);
    wire signed [WL-FRAC:0] corr = (total + HALF) >>> FRAC;

    // THE MEMORY, in the canonical form that Quartus maps to M10K: synchronous
    // write + synchronous read through a REGISTERED address, in the same block.
    // There is NO read/write conflict: at an anchor `ia` is written and `ia+2` is
    // read (and the ROM, `ia+1`), always different addresses, since N_ANCHORS > 2.
    always @(posedge clk) begin
        if (!rst && step) s_ram[ia] <= s_new;
        s_b <= s_ram[a_s];
        rc  <= recip[a_r];
    end

    always @(posedge clk) begin
        if (rst) begin
            // the reset clears the LEVEL and the accumulator, but NOT the shape
            // RAM: the loaded table survives the reset, which is the right
            // behavior for a shape that comes from a calibration.
            l_reg      <= L_INIT[WL-1:0];
            acc        <= {WA{1'b0}};
            inc        <= {WA{1'b0}};
            ia         <= IA_INIT[IAW-1:0];
            y          <= {BITS_IN{1'b0}};
            correction <= {BITS_IN{1'b0}};
            // start of the prefetch: at reset s[IA_INIT] and recip[IA_INIT] are
            // read; in the next cycle (`prime`) s_a takes s_b and s[IA_INIT+1] is read.
            ra_s       <= (IA_INIT[IAW-1:0] == N_ANCHORS-1) ? {IAW{1'b0}}
                                                            : IA_INIT[IAW-1:0] + 1'b1;
            ra_r       <= IA_INIT[IAW-1:0];
            prime      <= 1'b1;
        end else begin
            prime <= 1'b0;
            if (prime) s_a <= s_b;          // completes the start of the prefetch
            if (valid) begin
                if (anchor) begin
                    l_reg <= l_next[WL-1:0];
                    ia    <= ia_next;
                    inc   <= inc_new;
                    s_a   <= s_b;           // s[ia+1] becomes the s[ia] of the next
                    ra_s  <= ia_p2;
                    ra_r  <= ia_next;
                end
                acc        <= acc_eff;
                correction <= corr[BITS_IN-1:0];
                y          <= x - corr[BITS_IN-1:0];
            end
        end
    end

endmodule
