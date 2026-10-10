import gameService from '../services/game.service.js';

class GameController {
  /**
   * GET /v1/games/catalog or /v1/games
   */
  async getCatalog(req, res, next) {
    try {
      const { activeOnly } = req.query;
      const games = await gameService.getCatalog({ activeOnly: activeOnly === 'true' });
      return res.status(200).json({
        success: true,
        message: 'Official 6-Game skill catalog retrieved successfully',
        data: games,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /v1/games/:id
   */
  async getGameById(req, res, next) {
    try {
      const { id } = req.params;
      const game = await gameService.getGameById(id);
      return res.status(200).json({
        success: true,
        data: game,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/sessions
   */
  async createSession(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { game_id, gameId, mode, room_id, roomId } = req.body;
      const result = await gameService.createSession({
        userId,
        gameId: game_id || gameId,
        mode,
        roomId: room_id || roomId,
      });
      return res.status(201).json({
        success: true,
        message: 'Game session created',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/sessions/:id/events
   */
  async recordEvents(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { id } = req.params;
      const { events } = req.body;
      const result = await gameService.recordSessionEvents({
        userId,
        sessionId: id,
        events: Array.isArray(events) ? events : [req.body],
      });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/sessions/:id/finish
   */
  async finishSession(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { id } = req.params;
      const { score, duration_ms, durationMs, stats, final_hmac } = req.body;
      const result = await gameService.finishSession({
        userId,
        sessionId: id,
        score,
        durationMs: duration_ms || durationMs,
        stats: stats || {},
        finalHmac: final_hmac,
      });
      return res.status(200).json({
        success: true,
        message: 'Session finished and validated',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /v1/games/rp/wallet
   */
  async getRpWallet(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const wallet = await gameService.getRpWallet(userId);
      return res.status(200).json({
        success: true,
        data: wallet,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /v1/games/shop
   */
  async getShop(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { game_id, gameId } = req.query;
      const shop = await gameService.getShopCatalog(userId, game_id || gameId);
      return res.status(200).json({
        success: true,
        data: shop,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/shop/buy
   */
  async buyShopItem(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { item_id, itemId, currency } = req.body;
      const result = await gameService.buyShopItem({
        userId,
        itemId: item_id || itemId,
        currency,
      });
      return res.status(200).json({
        success: true,
        message: 'Item purchased successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /v1/games/energy
   */
  async getEnergy(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const energy = await gameService.getEnergy(userId);
      return res.status(200).json({
        success: true,
        data: energy,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/energy/refill
   */
  async refillEnergy(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { method } = req.body;
      const result = await gameService.refillEnergy({ userId, method });
      return res.status(200).json({
        success: true,
        message: 'Energy refilled',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /v1/games/leaderboards/:id
   */
  async getLeaderboard(req, res, next) {
    try {
      const { id } = req.params;
      const { period } = req.query;
      const board = await gameService.getLeaderboard(id, period);
      return res.status(200).json({
        success: true,
        data: board,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /v1/games/missions
   */
  async getMissions(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const missions = await gameService.getMissions(userId);
      return res.status(200).json({
        success: true,
        data: missions,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/missions/:id/claim
   */
  async claimMission(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { id } = req.params;
      const result = await gameService.claimMission(userId, id);
      return res.status(200).json({
        success: true,
        message: 'Mission reward claimed',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Module 01: GET /v1/games/rocket/progress
   */
  async getRocketProgress(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const progress = await gameService.getRocketProgress(userId);
      return res.status(200).json({
        success: true,
        message: 'Rocket game 5-level targets & progress retrieved',
        data: progress,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Module 01: POST /v1/games/rocket/contribute
   */
  async contributeRocket(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id || 'guest_user';
      const { coins } = req.body;
      const result = await gameService.contributeRocket(userId, { coins });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Module 01: GET /v1/admin/games/rocket/targets
   */
  async getRocketTargetsAdmin(req, res, next) {
    try {
      const result = await gameService.getRocketAdminConfig();
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Module 01: PUT /v1/admin/games/rocket/targets
   */
  async updateRocketTargetsAdmin(req, res, next) {
    try {
      const { targets } = req.body;
      const result = await gameService.updateRocketAdminConfig({ targets });
      return res.status(200).json({
        success: true,
        message: 'Rocket targets updated successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

export default new GameController();
