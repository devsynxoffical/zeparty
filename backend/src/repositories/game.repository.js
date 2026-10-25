import { CANONICAL_GAMES, getCanonicalGame } from '../constants/game.constants.js';

/**
 * Catalog view of the ten ZeParty premium games. Match state, rooms, wallets
 * and leaderboards live in the games service (`zeparty_games/backend`); this
 * repository only exposes the static catalog in the shape the mobile app and
 * the admin portal expect.
 */
class GameRepository {
  _toCatalogRow(game) {
    return {
      ...game,
      type: game.category,
      status: game.isActive ? 'active' : 'inactive',
      // Entertainment-only games: no entry fee, no prize pool.
      entryFee: 0,
      totalRounds: 0,
      totalPaidOut: 0,
      houseEdge: 0,
      minPrize: 0,
      maxPrize: 0,
      specificationStatus: 'live',
    };
  }

  async getCatalog({ activeOnly = false } = {}) {
    return CANONICAL_GAMES
      .map((g) => this._toCatalogRow(g))
      .filter((g) => (activeOnly ? g.isActive : true));
  }

  async findById(gameId) {
    const canonical = getCanonicalGame(gameId);
    if (!canonical) return null;
    return this._toCatalogRow(canonical);
  }
}

export default new GameRepository();
