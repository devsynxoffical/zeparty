import prisma from '../config/database.js';
import { CANONICAL_GAMES, getCanonicalGame, isValidGameId, DAILY_RP_CAP, MAX_ENERGY, ENERGY_REFILL_MINUTES } from '../constants/game.constants.js';

class GameRepository {
  /**
   * Returns list of canonical 6 games with runtime status & configs
   */
  async getCatalog({ activeOnly = false } = {}) {
    let dbGames = [];
    try {
      dbGames = await prisma.game.findMany();
    } catch (err) {
      dbGames = [];
    }

    const dbMap = new Map();
    dbGames.forEach((g) => {
      dbMap.set(g.gameKey, g);
    });

    return CANONICAL_GAMES.map((canonical) => {
      const dbRecord = dbMap.get(canonical.gameKey);
      return {
        ...canonical,
        dbId: dbRecord?.id || null,
        isActive: dbRecord ? dbRecord.isActive : canonical.isActive,
      };
    }).filter((g) => (activeOnly ? g.isActive : true));
  }

  /**
   * Find canonical game by ID or GameKey
   */
  async findById(gameId) {
    const canonical = getCanonicalGame(gameId);
    if (!canonical) return null;

    try {
      const dbRecord = await prisma.game.findFirst({
        where: { gameKey: canonical.gameKey },
      });

      return {
        ...canonical,
        dbId: dbRecord?.id || null,
        isActive: dbRecord ? dbRecord.isActive : canonical.isActive,
      };
    } catch (err) {
      return { ...canonical, dbId: null };
    }
  }

  /**
   * Toggle Game Active State in DB
   */
  async setGameStatus(gameKey, isActive) {
    return prisma.game.upsert({
      where: { gameKey },
      update: { isActive },
      create: {
        gameKey,
        name: getCanonicalGame(gameKey)?.name || gameKey,
        category: getCanonicalGame(gameKey)?.category || 'Skill',
        isActive,
      },
    });
  }
}

export default new GameRepository();
