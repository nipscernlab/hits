// F14 — o estimador de linha de base COMPLETO (etapa 2): rastreador de nivel
// + forma por BCID + interpolacao por acumulador de inclinacao.
//
//   a cada ANCORA i:  L    += (x - s[i] - L) >> K_NIVEL
//                     s[i] += ((x - L) - s[i]) >> K_FORMA      // streaming
//   a cada amostra:   y     = x - round(L + interp(s))
//
// ⚠️ x e' o DESVIO em relacao ao pedestal, com sinal. `ancora` vem da mascara
// do trem (slot vazio ha >= 13 BC), nao de deteccao por limiar.
//
// ⭐ L E s VIVEM NA MESMA MALHA FRACIONARIA (FRAC bits) — somam-se direto e ha
// UM UNICO arredondamento no fim. Arredondar a forma para ADC inteiro antes de
// somar joga fora a fracao e custa parte do ganho.
//
// ⭐ A INTERPOLACAO NAO TEM DIVISOR NO CAMINHO DE DADOS. Entre a ancora i e a
// seguinte, separadas por N slots, a forma anda em rampa:
//     na ancora:  inc = (s[i+1] - s[i]) * recip[i] >> (R - FRAC_I)   // 1 produto
//                 acc = s[i] << FRAC_I
//     nos demais: acc += inc
// `recip[i] = round(2^R / N)` sai de uma ROM porque a MASCARA E' ESTATICA: os N
// sao conhecidos em tempo de projeto. O produto e' UM POR ANCORA (654 por
// orbita, ~7,3 por microssegundo), nao um por slot — um multiplicador basta.
// ⚠️ E 631 dos 654 vaos tem N = 1 (dentro de um bloco de ancoras os slots
// vazios sao consecutivos); so os 23 vaos ENTRE blocos sao longos (92-135).
//
// ⚠️⚠️ ZONA MORTA — a armadilha que vale para os DOIS shifts: sem bits de
// fracao, `>> K` de algo menor que 2^K da zero e o filtro para de aprender. No
// `>> K_FORMA` (8) o incremento e' 16x menor que no `>> K_NIVEL` (4), entao la
// e' PIOR: medido na F14, com FRAC = 0 a forma nao apenas para de ajudar, ela
// PIORA o estimador (1,496 contra 1,420 sem forma nenhuma). Nao dá erro.

module estimador_baseline #(
    parameter integer BITS_IN = 13,   // largura de x, com sinal
    parameter integer FRAC    = 6,    // fracao de L e de s (a MESMA malha)
    parameter integer FRAC_I  = 6,    // fracao do acumulador de interpolacao
    parameter integer K_NIVEL = 4,    // memoria do nivel: 2^K ancoras
    parameter integer K_FORMA = 8,    // memoria da forma: 2^K orbitas
    parameter integer N_ANC   = 654,  // ancoras por orbita (da mascara)
    parameter integer R       = 16,   // bits do reciproco
    parameter integer WS      = 14,   // largura de s[i] (cabe 1 bloco M9K)
    parameter RECIP_MEM       = "recip.mem",
    // ⭐ ARRANQUE CARREGADO: na operacao real a forma e o nivel vem de uma
    // tabela (banco de dados / run de calibracao), nao de zero. S_INIT_MEM = ""
    // parte do zero e a forma leva ~2^K_FORMA orbitas (~23 ms) p/ convergir.
    parameter S_INIT_MEM      = "",
    parameter signed [31:0] L_INIT = 0,  // nivel inicial, na malha de FRAC bits
    // ⚠️⚠️ FASE DO INDICE DE ANCORA. `ia` conta ancoras e endereca a ROM de
    // reciprocos, que descreve o vao ATE A PROXIMA ancora. Se `ia` arrancar
    // fora de fase, recip[ia] e' o vao de OUTRA ancora — e como 631 dos 654
    // vaos tem N = 1, nos 23 vaos LONGOS a rampa dispara com o reciproco de um
    // vao curto. O erro nao aparece nas ancoras (elas continuam sendo ajustadas):
    // ele explode ENTRE elas, e nao ha aviso nenhum.
    // Uma vez em fase, nao ha deriva: sao exatamente N_ANC ancoras por orbita.
    // O valor depende de onde a orbita comeca e do pipeline — MEDIR, nao supor.
    parameter integer IA_INIT = 0
)(
    input  wire                      clk,
    input  wire                      rst,     // sincrono, ativo alto
    input  wire                      valid,
    input  wire signed [BITS_IN-1:0] x,       // desvio vs pedestal
    input  wire                      ancora,
    output reg  signed [BITS_IN-1:0] y,       // x - correcao
    output reg  signed [BITS_IN-1:0] correcao // a correcao aplicada, p/ debug
);

    // ⚠️⚠️ A ROM tem R+1 BITS, nao R: 631 dos 654 vaos tem N = 1, e
    // round(2^R / 1) = 2^R, que NAO cabe em R bits. Com R bits o valor trunca
    // para zero e a interpolacao morre nos vaos curtos — em silencio.
    localparam integer WR   = R + 1;               // largura do reciproco
    localparam integer WL   = BITS_IN + FRAC;      // largura de L
    localparam integer WA   = WS + FRAC_I + 2;     // largura do acumulador
    localparam integer WI   = WS + 1 + WR;         // largura do produto
    localparam integer IAW  = $clog2(N_ANC);
    localparam signed [WL:0] MEIO = (FRAC > 0) ? (1 <<< (FRAC - 1)) : 0;

    // ⚠️ SINTESE: leitura de dois enderecos por ciclo ⇒ RAM DUAL-PORT.
    reg signed [WS-1:0]  s_ram [0:N_ANC-1];
    reg        [WR-1:0]  recip [0:N_ANC-1];

    reg signed [WL-1:0]  l_reg;
    reg signed [WA-1:0]  acc;
    reg signed [WA-1:0]  inc;
    reg        [IAW-1:0] ia;

    integer k;
    initial begin
        $readmemh(RECIP_MEM, recip);
        for (k = 0; k < N_ANC; k = k + 1) s_ram[k] = {WS{1'b0}};
        if (S_INIT_MEM != "") $readmemh(S_INIT_MEM, s_ram);
    end

    wire [IAW-1:0] ia_prox = (ia == N_ANC-1) ? {IAW{1'b0}} : ia + 1'b1;

    wire signed [WS:0] s_cur  = $signed({s_ram[ia][WS-1],  s_ram[ia]});
    wire signed [WS:0] s_prox = $signed({s_ram[ia_prox][WS-1], s_ram[ia_prox]});

    // x promovido a malha fracionaria
    wire signed [WL:0] x_ext = $signed({{(FRAC+1){x[BITS_IN-1]}}, x}) <<< FRAC;
    wire signed [WL:0] l_ext = $signed({l_reg[WL-1], l_reg});

    // --- nivel: L += (x - s[i] - L) >> K_NIVEL   (so em ancora)
    wire signed [WL:0] d_niv  = x_ext - s_cur - l_ext;
    wire signed [WL:0] l_prox = l_ext + (d_niv >>> K_NIVEL);
    wire signed [WL:0] l_efet = ancora ? l_prox : l_ext;

    // --- forma: s[i] += ((x - L) - s[i]) >> K_FORMA, com o L JA atualizado
    wire signed [WL:0] d_frm = (x_ext - l_prox) - s_cur;
    wire signed [WL:0] s_new_w = s_cur + (d_frm >>> K_FORMA);
    wire signed [WS-1:0] s_new = s_new_w[WS-1:0];

    // --- interpolacao: recarrega na ancora, acumula nos demais
    wire signed [WI-1:0] prod = ($signed(s_prox) - $signed({s_new[WS-1], s_new}))
                                * $signed({1'b0, recip[ia]});   // 1 produto/âncora
    wire signed [WA-1:0] inc_novo = prod >>> (R - FRAC_I);
    wire signed [WA-1:0] acc_efet = ancora ? ($signed({s_new[WS-1], s_new}) <<< FRAC_I)
                                           : (acc + inc);

    // --- soma na malha comum e UM arredondamento
    wire signed [WL:0] total = l_efet + $signed(acc_efet >>> FRAC_I);
    wire signed [WL-FRAC:0] corr = (total + MEIO) >>> FRAC;

    always @(posedge clk) begin
        if (rst) begin
            // ⚠️ o reset zera o NIVEL e o acumulador, mas NAO a RAM da forma:
            // a tabela carregada sobrevive ao reset, que e' o comportamento
            // certo p/ uma forma vinda de calibracao.
            l_reg    <= L_INIT[WL-1:0];
            acc      <= {WA{1'b0}};
            inc      <= {WA{1'b0}};
            ia       <= IA_INIT[IAW-1:0];
            y        <= {BITS_IN{1'b0}};
            correcao <= {BITS_IN{1'b0}};
        end else if (valid) begin
            if (ancora) begin
                l_reg      <= l_prox[WL-1:0];
                s_ram[ia]  <= s_new;
                ia         <= ia_prox;
                inc        <= inc_novo;
            end
            acc        <= acc_efet;
            correcao   <= corr[BITS_IN-1:0];
            y          <= x - corr[BITS_IN-1:0];
        end
    end

endmodule
