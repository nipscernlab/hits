"""Seeds for xoshiro128** instances that provably never overlap.

The xoshiro128 jump advances a state by exactly 2^64 steps (Blackman and Vigna,
https://prng.di.unimi.it/xoshiro128starstar.c). Starting from the hit
generator's seed, stage k gets the state jumped k times, so every stream owns
its own 2^64-long stretch of the 2^128 - 1 cycle. The script also checks the
jump against the transition matrix raised to 2^64 (GF(2) squaring), so the
constants are not taken on faith.

    python rtl/random/xoshiro_jump.py [N]          # N jumped states (default 2)
    python rtl/random/xoshiro_jump.py canais C     # the XO_SEED_* parameters of C channels

Prints SEED0..SEED3 for each stage, in the order rng_xoshiro.v takes them
(SEED0 = s0, ..., SEED3 = s3). With "canais", channel k gets the jumps 3k, 3k+1
and 3k+2 (hit, energy, noise) as the 128-bit XO_SEED_HIT, XO_SEED_ENERGY and
XO_SEED_NOISE parameters of hits_simulator ({s3, s2, s1, s0}); channel 0 is the
default.

The phase draw (2026-10-17) is a fourth stream per channel. Putting it in the
3k scheme would move the seeds of every channel but 0, so it takes the LONG
jump instead (2^96 steps, same source) of the channel's hit seed:
XO_SEED_PHASE = long_jump(XO_SEED_HIT). The 3k streams of channel k sit at
3k * 2^64 from the hit seed, far below 2^96 for any realistic k, so the phase
stream never meets them. Checked against the matrix raised to 2^96.
"""
import sys

M = 0xFFFFFFFF
HIT_SEED = [461934351, 363409739, 209805534, 3049884771]  # rtl/hits/hit_generator.v
JUMP = [0x8764000B, 0xF542D2D3, 0x6FA035C3, 0x77F2DB5B]
LONG_JUMP = [0xB523952E, 0x0B6F099F, 0xCCF5A0EF, 0x1C580662]


def rotl(x, k):
    return ((x << k) | (x >> (32 - k))) & M


def step(s):  # the state update of rng_xoshiro.v
    s0, s1, s2, s3 = s
    t = (s1 << 9) & M
    s2 ^= s0
    s3 ^= s1
    s1 ^= s2
    s0 ^= s3
    s2 ^= t
    return [s0, s1, s2, rotl(s3, 11)]


def jump(s, consts=JUMP):
    acc = [0, 0, 0, 0]
    for w in consts:
        for b in range(32):
            if w >> b & 1:
                acc = [a ^ x for a, x in zip(acc, s)]
            s = step(s)
    return acc


def pack(s):
    return s[0] | s[1] << 32 | s[2] << 64 | s[3] << 96


def unpack(v):
    return [(v >> (32 * i)) & M for i in range(4)]


def apply(cols, v):
    r, i = 0, 0
    while v:
        if v & 1:
            r ^= cols[i]
        v >>= 1
        i += 1
    return r


def matrix_jump(e=64):
    """Columns of T^(2^e), T the one-step transition over GF(2)^128."""
    cols = [pack(step(unpack(1 << i))) for i in range(128)]
    for _ in range(e):
        cols = [apply(cols, c) for c in cols]
    return cols


def long_jump(s, t96=None):
    out = jump(s, LONG_JUMP)
    if t96 is not None:
        assert pack(out) == apply(t96, pack(s)), "long jump constants disagree with T^(2^96)"
    return out


def verilog(s):
    return "{" + ", ".join(f"32'd{v}" for v in reversed(s)) + "}"


def canais(c):
    t64 = matrix_jump()
    t96 = matrix_jump(96)
    s = HIT_SEED
    for k in range(c):
        out = []
        for _ in range(3):
            out.append(s)
            nxt = jump(s)
            assert pack(nxt) == apply(t64, pack(s)), "jump constants disagree with T^(2^64)"
            s = nxt
        print(f"canal {k}: .XO_SEED_HIT({verilog(out[0])}), .XO_SEED_ENERGY({verilog(out[1])}), "
              f".XO_SEED_NOISE({verilog(out[2])}), .XO_SEED_PHASE({verilog(long_jump(out[0], t96))})")


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "canais":
        canais(int(sys.argv[2]))
        return
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    t64 = matrix_jump()
    s = HIT_SEED
    print("stage 0 (hit):", s)
    for k in range(1, n + 1):
        nxt = jump(s)
        assert pack(nxt) == apply(t64, pack(s)), "jump constants disagree with T^(2^64)"
        s = nxt
        print(f"stage {k}:", s)
    print("phase (long jump of the hit seed):", long_jump(HIT_SEED, matrix_jump(96)))


if __name__ == "__main__":
    main()
