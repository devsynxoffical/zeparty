import { randomBytes } from 'node:crypto';
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I ambiguity
/** 12 char unpredictable room id (60 bits of entropy from crypto). */
export function newRoomId() {
    return randomToken(12);
}
/** Short human-typable invite code, 6 chars, 30 bits. Checked together with roomId. */
export function newInviteCode() {
    return randomToken(6);
}
export function newMatchId() {
    return `m_${randomToken(16)}`;
}
function randomToken(length) {
    const bytes = randomBytes(length);
    let out = '';
    for (let i = 0; i < length; i++)
        out += ALPHABET[(bytes[i] ?? 0) % ALPHABET.length];
    return out;
}
