// ============================================================
// ZeParty Admin Portal — Games Service (JavaScript)
// ============================================================

import { MOCK_GAMES } from '../../mocks/games.mock';

let gamesState = [...MOCK_GAMES];

export async function getGames() {
  await new Promise((res) => setTimeout(res, 150));
  return [...gamesState];
}

export async function toggleGameStatus(id) {
  await new Promise((res) => setTimeout(res, 200));
  gamesState = gamesState.map((g) =>
    g.id === id ? { ...g, status: g.status === 'active' ? 'inactive' : 'active' } : g
  );
  return { success: true };
}

export async function updateGameConfig(id, config, operatorName = 'Super Admin', changeReason = 'Updated game configuration') {
  await new Promise((res) => setTimeout(res, 250));
  let updatedGame = null;

  gamesState = gamesState.map((g) => {
    if (g.id === id) {
      // Calculate outcomes probability validation and metrics
      const outcomes = config.outcomes || g.outcomes || [];
      const totalProb = outcomes.reduce((acc, out) => (out.active ? acc + Number(out.probability || 0) : acc), 0);
      
      if (Math.abs(totalProb - 100) > 0.001) {
        throw new Error(`Invalid Configuration: Total probability must sum to exactly 100% (Current: ${totalProb}%).`);
      }

      const expectedReturn = outcomes.reduce((acc, out) => {
        if (!out.active) return acc;
        return acc + (Number(out.probability || 0) / 100) * Number(out.payout || 0);
      }, 0);
      
      const derivedHouseEdge = Number(((1 - expectedReturn) * 100).toFixed(2));
      const nextVersion = `v1.${(g.history || []).length}`;

      const historyRecord = {
        version: nextVersion,
        effectiveDate: new Date().toISOString(),
        operator: operatorName,
        reason: changeReason,
        expectedReturn: Number(expectedReturn.toFixed(4)),
        houseEdge: derivedHouseEdge,
        outcomesCount: outcomes.filter(o => o.active).length
      };

      updatedGame = {
        ...g,
        name: config.name || g.name,
        type: config.type || g.type,
        status: config.status || g.status,
        entryFee: Number(config.entryFee !== undefined ? config.entryFee : g.entryFee),
        minPrize: Number(config.minPrize !== undefined ? config.minPrize : g.minPrize),
        maxPrize: Number(config.maxPrize !== undefined ? config.maxPrize : g.maxPrize),
        dailyPlayLimit: Number(config.dailyPlayLimit || g.dailyPlayLimit || 50),
        userLevelLimit: Number(config.userLevelLimit || g.userLevelLimit || 1),
        isEventSpecific: !!config.isEventSpecific,
        startDate: config.startDate || '',
        endDate: config.endDate || '',
        description: config.description || g.description,
        outcomes: outcomes,
        expectedReturn: Number(expectedReturn.toFixed(4)),
        houseEdge: derivedHouseEdge,
        history: [historyRecord, ...(g.history || [])]
      };
      
      return updatedGame;
    }
    return g;
  });

  if (!updatedGame) {
    throw new Error('Game not found.');
  }

  return updatedGame;
}
