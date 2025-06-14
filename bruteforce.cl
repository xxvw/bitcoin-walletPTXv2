// SHA256の定数
__constant uint k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
};

// SHA256の初期値
__constant uint h0[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

// 外部アセンブリ関数の宣言
extern void generate_seed_asm(
    __private char* current_seed,
    __global const char* wordlist,
    __global const int* wordlist_size,
    uint idx
);

// 文字列比較関数
int fast_strcmp(__global const char* s1, __global const char* s2) {
    int i = 0;
    while (s1[i] != '\0' && s2[i] != '\0') {
        if (s1[i] != s2[i]) return 1;
        i++;
    }
    return (s1[i] == s2[i]) ? 0 : 1;
}

// SHA256の変換関数
void sha256_transform(__private uint* state, __private const uint* block) {
    uint a, b, c, d, e, f, g, h, i, j, t1, t2, m[64];

    for (i = 0, j = 0; i < 16; ++i, j += 4) {
        m[i] = (block[j] << 24) | (block[j + 1] << 16) | (block[j + 2] << 8) | (block[j + 3]);
    }

    for (; i < 64; ++i) {
        m[i] = m[i - 16] + m[i - 7] +
            ((m[i - 15] >> 7) | (m[i - 15] << 25)) +
            ((m[i - 2] >> 17) | (m[i - 2] << 15));
    }

    a = state[0];
    b = state[1];
    c = state[2];
    d = state[3];
    e = state[4];
    f = state[5];
    g = state[6];
    h = state[7];

    for (i = 0; i < 64; ++i) {
        t1 = h + ((e >> 6) | (e << 26)) + ((e >> 11) | (e << 21)) + ((e >> 25) | (e << 7)) +
             ((e & f) ^ (~e & g)) + k[i] + m[i];
        t2 = ((a >> 2) | (a << 30)) + ((a >> 13) | (a << 19)) + ((a >> 22) | (a << 10)) +
             ((a & b) ^ (a & c) ^ (b & c));
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

// メインカーネル
__kernel void bruteforce_kernel(
    __global const char* wordlist,
    __global const int* wordlist_size,
    __global const char* target_hash,
    __global char* result,
    __global int* found
) {
    uint idx = get_global_id(0);
    uint state[8];
    char current_seed[1024];
    int i;

    // 初期状態のコピー
    for (i = 0; i < 8; i++) {
        state[i] = h0[i];
    }

    // アセンブリで最適化されたシード生成
    generate_seed_asm(current_seed, wordlist, wordlist_size, idx);

    // SHA256ハッシュの計算
    sha256_transform(state, (uint*)current_seed);

    // ハッシュの比較
    if (fast_strcmp((char*)state, target_hash) == 0) {
        *found = 1;
        for (i = 0; i < 1024; i++) {
            result[i] = current_seed[i];
        }
    }
} 