"""Leitor minimo de VCD do testbench do HITS -> vetores por amostra (borda de subida).

Amostra os sinais pedidos uma vez por periodo de clock (25 ns), na fase em que
o testbench os atualiza.
"""
import sys


def ler(path, nomes):
    ids, larg, sinal = {}, {}, {}
    with open(path) as f:
        # cabecalho
        for lin in f:
            lin = lin.strip()
            if lin.startswith("$var"):
                p = lin.split()
                w, ident, nome = int(p[2]), p[3], p[4]
                if nome in nomes:
                    ids[ident] = nome
                    larg[nome] = w
            elif lin.startswith("$enddefinitions"):
                break
        for n in nomes:
            sinal[n] = []
        atual = {n: 0 for n in nomes}
        t = 0
        clk_id = [i for i, n in ids.items() if n == "clk"]
        clk_id = clk_id[0] if clk_id else None
        clk = 0
        for lin in f:
            lin = lin.rstrip()
            if not lin:
                continue
            if lin[0] == "#":
                t = int(lin[1:])
                continue
            if lin[0] in "01xzXZ":            # escalar
                v, ident = lin[0], lin[1:]
                if ident == clk_id:
                    novo = 1 if v == "1" else 0
                    if novo == 1 and clk == 0:      # borda de subida
                        for n in nomes:
                            sinal[n].append(atual[n])
                    clk = novo
                elif ident in ids:
                    atual[ids[ident]] = 0 if v in "0xzXZ" else 1
            elif lin[0] in "bB":
                p = lin.split()
                bits, ident = p[0][1:], p[1]
                if ident in ids:
                    n = ids[ident]
                    bits = bits.replace("x", "0").replace("z", "0")
                    v = int(bits, 2) if bits else 0
                    w = larg[n]
                    if len(bits) == w and bits[0] == "1":
                        pass  # sinal cru; a conversao com sinal fica p/ quem chama
                    atual[n] = v
    return sinal, larg


def com_sinal(v, w):
    return v - (1 << w) if v & (1 << (w - 1)) else v


if __name__ == "__main__":
    s, w = ler(sys.argv[1], sys.argv[2].split(","))
    for n in s:
        print(n, "amostras:", len(s[n]), "largura:", w[n])
