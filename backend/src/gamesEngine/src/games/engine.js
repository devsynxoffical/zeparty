/** Deterministic PRNG (mulberry32) for tests and replay. Production uses CryptoRng. */
export class SeededRng {
    a;
    constructor(seed) {
        this.a = seed >>> 0;
    }
    float() {
        let t = (this.a += 0x6d2b79f5);
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    }
    int(min, max) {
        return min + Math.floor(this.float() * (max - min + 1));
    }
}
export class CryptoRng {
    crypto = globalThis.crypto;
    float() {
        const buf = new Uint32Array(1);
        this.crypto.getRandomValues(buf);
        return (buf[0] ?? 0) / 4294967296;
    }
    int(min, max) {
        // rejection sampling to avoid modulo bias
        const range = max - min + 1;
        const limit = Math.floor(4294967296 / range) * range;
        const buf = new Uint32Array(1);
        let v;
        do {
            this.crypto.getRandomValues(buf);
            v = buf[0] ?? 0;
        } while (v >= limit);
        return min + (v % range);
    }
}
export function isRealtimeEngine(e) {
    return typeof e.tick === 'function' && typeof e.tickRateHz === 'number';
}
