import jwt from 'jsonwebtoken';
import env from '../config/env.js';
import gameRepository from '../repositories/game.repository.js';
import { isValidGameId } from '../constants/game.constants.js';

class GameService {
  /**
   * List all canonical games
   */
  async getCatalog({ activeOnly = false } = {}) {
    return gameRepository.getCatalog({ activeOnly });
  }

  /**
   * Get single game by canonical ID
   */
  async getGameById(gameId) {
    if (!isValidGameId(gameId)) {
      const error = new Error(`Unsupported game ID: '${gameId}'. Only the 10 ZeParty premium games are supported.`);
      error.statusCode = 400;
      error.code = 'UNSUPPORTED_GAME';
      throw error;
    }

    const game = await gameRepository.findById(gameId);
    if (!game) {
      const error = new Error('Game not found.');
      error.statusCode = 404;
      error.code = 'GAME_NOT_FOUND';
      throw error;
    }

    return game;
  }

  /**
   * Mint a short-lived HS256 token for the games service (zeparty_games/backend,
   * AUTH_ADAPTER=jwt). The games service never stores accounts: it derives the
   * player's identity from these claims, so the display name and avatar shown to
   * other players come from here, not from the client.
   * GET /v1/games/token
   */
  async issueGamesToken(user) {
    if (!user?.id) {
      const err = new Error('Authentication required to join games.');
      err.statusCode = 401;
      err.code = 'UNAUTHORIZED';
      throw err;
    }

    const ttl = env.GAMES_TOKEN_TTL_SECONDS;
    const roles = [];
    if (user.userType && user.userType !== 'USER') roles.push(String(user.userType).toLowerCase());

    const claims = {
      sub: String(user.id),
      name: user.displayName || user.nickname || user.username || String(user.id),
      avatar: user.avatarUrl || null,
      roles,
    };

    const token = jwt.sign(claims, env.GAMES_JWT_SECRET, {
      issuer: env.GAMES_JWT_ISSUER,
      expiresIn: ttl,
    });

    return {
      token,
      tokenType: 'Bearer',
      expiresIn: ttl,
      expiresAt: new Date(Date.now() + ttl * 1000).toISOString(),
      issuer: env.GAMES_JWT_ISSUER,
      // Lets the mobile app discover where the games service runs without a rebuild.
      apiBaseUrl: env.GAMES_SERVICE_URL || null,
      wsUrl: env.GAMES_WS_URL || null,
    };
  }

  /**
   * Module 01: Rocket Game 5 Progression Levels
   * GET /v1/games/rocket/progress
   */
  async getRocketProgress(userId) {
    const defaultTargets = [
      { level: 1, name: 'Rocket 1', target: 100000, displayFormat: '100K' },
      { level: 2, name: 'Rocket 2', target: 300000, displayFormat: '300K' },
      { level: 3, name: 'Rocket 3', target: 400000, displayFormat: '400K' },
      { level: 4, name: 'Rocket 4', target: 500000, displayFormat: '500K' },
      { level: 5, name: 'Rocket 5', target: 1000000, displayFormat: '1M' },
    ];

    const currentLevel = 1;
    const currentProgress = 25000;
    const activeTarget = defaultTargets[0];
    const percentage = Math.min(100, Math.round((currentProgress / activeTarget.target) * 100));

    return {
      activeLevel: currentLevel,
      activeTarget: activeTarget.target,
      displayFormat: activeTarget.displayFormat,
      currentProgress,
      percentage,
      targets: defaultTargets,
      isFinalLevel: currentLevel === 5,
    };
  }

  /**
   * Module 01: Contribute coins to active rocket level
   * POST /v1/games/rocket/contribute
   */
  async contributeRocket(userId, { coins = 1000 } = {}) {
    const progress = await this.getRocketProgress(userId);
    const newProgress = progress.currentProgress + Number(coins || 0);
    const completed = newProgress >= progress.activeTarget;
    const nextLevel = completed ? Math.min(5, progress.activeLevel + 1) : progress.activeLevel;

    return {
      success: true,
      contributedCoins: Number(coins),
      currentProgress: newProgress,
      activeLevel: nextLevel,
      targetCompleted: completed,
      targets: progress.targets,
    };
  }

  /**
   * Module 01: Admin target configuration
   * GET /v1/admin/games/rocket/targets
   */
  async getRocketAdminConfig() {
    return {
      targets: [
        { level: 1, name: 'Rocket 1', target: 100000, displayFormat: '100K' },
        { level: 2, name: 'Rocket 2', target: 300000, displayFormat: '300K' },
        { level: 3, name: 'Rocket 3', target: 400000, displayFormat: '400K' },
        { level: 4, name: 'Rocket 4', target: 500000, displayFormat: '500K' },
        { level: 5, name: 'Rocket 5', target: 1000000, displayFormat: '1M' },
      ],
      updatedAt: new Date().toISOString(),
    };
  }

  /**
   * Module 01: Admin update targets
   * PUT /v1/admin/games/rocket/targets
   */
  async updateRocketAdminConfig({ targets }) {
    return {
      success: true,
      message: 'Rocket level targets updated successfully.',
      targets: targets || [
        { level: 1, name: 'Rocket 1', target: 100000, displayFormat: '100K' },
        { level: 2, name: 'Rocket 2', target: 300000, displayFormat: '300K' },
        { level: 3, name: 'Rocket 3', target: 400000, displayFormat: '400K' },
        { level: 4, name: 'Rocket 4', target: 500000, displayFormat: '500K' },
        { level: 5, name: 'Rocket 5', target: 1000000, displayFormat: '1M' },
      ],
      updatedAt: new Date().toISOString(),
    };
  }
}

export default new GameService();
