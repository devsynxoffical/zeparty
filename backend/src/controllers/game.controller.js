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
        message: 'ZeParty premium games catalog retrieved successfully',
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
   * GET /v1/games/token
   */
  async getGamesToken(req, res, next) {
    try {
      const result = await gameService.issueGamesToken(req.user, req);
      return res.status(200).json({
        success: true,
        message: 'Games service token issued',
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
      try {
        const { recordActivity } = await import('../services/quest.service.js');
        await recordActivity(userId, 'MINI_GAME', { gameId: 'rocket', coins });
      } catch (_) {}
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * POST /v1/games/activity
   * Records verified mini-game participation for daily quest tracking.
   */
  async recordGameActivity(req, res, next) {
    try {
      const userId = req.auth?.userId || req.user?.id;
      if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });
      const { gameId } = req.body || {};
      const { recordActivity } = await import('../services/quest.service.js');
      await recordActivity(userId, 'MINI_GAME', { gameId: gameId || 'mini_game' });
      return res.status(200).json({ success: true, message: 'Mini-game activity recorded successfully' });
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
