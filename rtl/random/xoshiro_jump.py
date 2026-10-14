"""Seeds for xoshiro128** instances that provably never overlap.

The xoshiro128 jump advances a state by exactly 2^64 steps (Blackman and Vigna,
https://prng.di.unimi.it/xoshiro128starstar.c). Starting from the hit
generator's seed, stage k gets the state jumped k times, so every stream owns
its own 2^64-long stretch of the 2^128 - 1 cycle. The script also checks the
jump against the transition matrix raised to 2^64 (GF(2) squaring), so the
constants are not taken on faith.

    python rtl/random/xoshiro_jump.py [N]   # N jumped states (default 2)

Prints SEED0..SEED3 for each stage, in the order rng_xoshiro.v takes them
(SEED0 = s0, ..., SEED3 = s3).
"""
import sys

M = 0xFFFFFFFF
HIT_SEED = [461934351, 363409739, 209805534, 3049884771]  # rtl/hits/hit_generator.v
JUMP = [0x8764000B, 0xF542D2D3, 0x6FA035C3, 0x77F2DB5B]


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


def jump(s):
    acc = [0, 0, 0, 0]
    for w in JUMP:
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


def matrix_jump():
    """Columns of T^(2^64), T the one-step transition over GF(2)^128."""
    cols = [pack(step(unpack(1 << i))) for i in range(128)]
    for _ in range(64):
        cols = [apply(cols, c) for c in cols]
    return cols


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    t64 = matrix_jump()
    s = HIT_SEED
    print("stage 0 (hit):", s)
    for k in range(1, n + 1):
        nxt = jump(s)
        assert pack(nxt) == apply(t64, pack(s)), "jump constants disagree with T^(2^64)"
        s = nxt
        print(f"stage {k}:", s)


if __name__ == "__main__":
    main()
