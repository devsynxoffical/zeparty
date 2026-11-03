/** Public projection of a room for clients. */
export function toRoomView(room) {
    const { match, inviteCode, ...rest } = room;
    return { ...rest, inviteCode: room.isPrivate ? inviteCode : null, matchId: match?.matchId ?? null };
}
