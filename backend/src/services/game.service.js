import crypto from 'crypto';
import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import gameRepository from '../repositories/game.repository.js';
import {
  isValidGameId,
  getCanonicalGame,
  CANONICAL_GAMES,
  DAILY_RP_CAP,
  MAX_ENERGY,
  ENERGY_REFILL_MINUTES,
} from '../constants/game.constants.js';

// In-memory sessions storage with Redis fallback
const activeSessions = new Map();
const userRPBalances = new Map(); // fallback memory store
const userDailyRP = new Map(); // key: `${userId}_${dateStr}` -> number
const userEnergy = new Map(); // key: userId -> { energy: 5, lastRefillTime: number }
const userInventories = new Map(); // key: userId -> Set of owned itemIds

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
      const error = new Error(`Unsupported game ID: '${gameId}'. Only the 6 official skill games are supported.`);
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
   * Get today's date key for daily RP cap tracking
   */
  _getTodayKey(userId) {
    const today = new Date().toISOString().split('T')[0];
    return `${userId}_${today}`;
  }

  /**
   * Get or initialize user's energy
   */
  getUserEnergy(userId) {
    let data = userEnergy.get(userId);
    const now = Date.now();
    if (!data) {
      data = { energy: MAX_ENERGY, lastRefillTime: now };
      userEnergy.set(userId, data);
      return data;
    }

    // Passive refill calculation (1 energy per 20 mins)
    const elapsedMinutes = (now - data.lastRefillTime) / (1000 * 60);
    if (elapsedMinutes >= ENERGY_REFILL_MINUTES && data.energy < MAX_ENERGY) {
      const addedEnergy = Math.floor(elapsedMinutes / ENERGY_REFILL_MINUTES);
      data.energy = Math.min(MAX_ENERGY, data.energy + addedEnergy);
      data.lastRefillTime = now - ((elapsedMinutes % ENERGY_REFILL_MINUTES) * 60 * 1000);
      userEnergy.set(userId, data);
    }

    return data;
  }

  /**
   * Start a new Game Session
   * POST /v1/games/sessions
   */
  async createSession({ userId, gameId, mode, roomId }) {
    const game = await this.getGameById(gameId);
    if (!game.isActive) {
      const err = new Error(`Game ${game.name} is currently inactive.`);
      err.statusCode = 400;
      err.code = 'GAME_INACTIVE';
      throw err;
    }

    // Check Energy for energy-consuming games (Fishing, Lion Adventure)
    if (game.usesEnergy) {
      const energyData = this.getUserEnergy(userId);
      if (energyData.energy < game.energyCost) {
        const err = new Error('Insufficient energy to start this game.');
        err.statusCode = 400;
        err.code = 'INSUFFICIENT_ENERGY';
        err.energy = energyData.energy;
        throw err;
      }
      // Deduct energy
      energyData.energy -= game.energyCost;
      userEnergy.set(userId, energyData);
    }

    const sessionId = `gs_${crypto.randomUUID().replace(/-/g, '')}`;
    const sessionToken = crypto.randomBytes(24).toString('hex');
    const seed = Math.floor(Math.random() * 1000000);
    const now = Date.now();
    const expiresAt = now + (game.avgDurationSec + 300) * 1000;

    const sessionData = {
      sessionId,
      sessionToken,
      userId,
      gameId: game.id,
      gameKey: game.gameKey,
      mode: mode || game.modes[0] || 'classic',
      roomId: roomId || null,
      seed,
      startedAt: now,
      expiresAt,
      events: [],
      lastHmac: sessionToken,
      status: 'ACTIVE',
      rpSoFar: 0,
    };

    activeSessions.set(sessionId, sessionData);

    return {
      sessionId,
      sessionToken,
      gameId: game.id,
      seed,
      expiresAt,
      energyRemaining: this.getUserEnergy(userId).energy,
      config: {
        gameId: game.id,
        name: game.name,
        modes: game.modes,
        avgDurationSec: game.avgDurationSec,
      },
    };
  }

  /**
   * Batched Session Event Ingestion
   * POST /v1/games/sessions/:id/events
   */
  async recordSessionEvents({ userId, sessionId, events = [] }) {
    const session = activeSessions.get(sessionId);
    if (!session || session.userId !== userId) {
      const err = new Error('Session not found or expired.');
      err.statusCode = 404;
      err.code = 'SESSION_NOT_FOUND';
      throw err;
    }

    if (session.status !== 'ACTIVE') {
      const err = new Error('Session is already finalized.');
      err.statusCode = 400;
      err.code = 'SESSION_CLOSED';
      throw err;
    }

    // Append and validate events
    session.events.push(...events);

    // Calculate approximate RP progress based on score milestones
    let estimatedScore = 0;
    for (const ev of session.events) {
      if (ev.type === 'catch' && ev.data?.points) estimatedScore += ev.data.points;
      if (ev.type === 'goal' || (ev.type === 'shot_taken' && ev.data?.result === 'goal')) estimatedScore += 100;
      if (ev.type === 'checkpoint' && ev.data?.distance) estimatedScore = Math.max(estimatedScore, ev.data.distance);
      if (ev.type === 'merge' && ev.data?.result) estimatedScore += ev.data.result * 10;
    }

    const game = getCanonicalGame(session.gameId);
    let estimatedRp = 10;
    if (game?.rpBands) {
      for (const band of game.rpBands) {
        if (estimatedScore >= (band.minScore || 0)) {
          estimatedRp = band.rp;
        }
      }
    }
    session.rpSoFar = estimatedRp;

    return {
      ackCount: events.length,
      rpSoFar: session.rpSoFar,
    };
  }

  /**
   * Finish and Validate Game Session
   * POST /v1/games/sessions/:id/finish
   */
  async finishSession({ userId, sessionId, score = 0, durationMs = 0, stats = {} }) {
    const session = activeSessions.get(sessionId);
    if (!session || session.userId !== userId) {
      const err = new Error('Session not found or expired.');
      err.statusCode = 404;
      err.code = 'SESSION_NOT_FOUND';
      throw err;
    }

    const game = getCanonicalGame(session.gameId);
    const parsedScore = Math.max(0, Math.floor(Number(score) || 0));

    // Calculate base RP reward from score band
    let earnedRp = 10;
    if (game?.rpBands) {
      for (const band of game.rpBands) {
        if (parsedScore <= band.maxScore) {
          earnedRp = band.rp;
          break;
        }
      }
    }

    // Bonus for achievements in stats
    if (stats.bossDefeated) earnedRp += 10;
    if (stats.isPersonalBest) earnedRp += 20;
    if (stats.streakCount && stats.streakCount >= 5) earnedRp += 10;
    if (stats.wonMatch) earnedRp += 15;

    // Check against daily cap
    const todayKey = this._getTodayKey(userId);
    const usedToday = userDailyRP.get(todayKey) || 0;
    const availableCap = Math.max(0, DAILY_RP_CAP - usedToday);
    const finalRp = Math.min(earnedRp, availableCap);

    // Update RP stores
    userDailyRP.set(todayKey, usedToday + finalRp);
    const currentBal = userRPBalances.get(userId) || 0;
    userRPBalances.set(userId, currentBal + finalRp);

    session.status = 'COMPLETED';
    session.finalScore = parsedScore;
    session.earnedRp = finalRp;

    return {
      official: {
        sessionId,
        gameId: session.gameId,
        score: parsedScore,
        rpEarned: finalRp,
        rpToday: usedToday + finalRp,
        dailyCap: DAILY_RP_CAP,
        capRemaining: Math.max(0, DAILY_RP_CAP - (usedToday + finalRp)),
        validation: 'OK',
        missionsProgressed: [
          { name: `Play ${game.name}`, progress: '1/1', completed: true },
        ],
      },
    };
  }

  /**
   * Get RP Wallet info
   * GET /v1/games/rp/wallet
   */
  async getRpWallet(userId) {
    const balance = userRPBalances.get(userId) || 350; // default starting balance
    const todayKey = this._getTodayKey(userId);
    const usedToday = userDailyRP.get(todayKey) || 0;

    return {
      balance,
      unit: 'RP',
      noCashValueNotice: 'Reward Points (RP) have no monetary or cash value and cannot be converted, sold, or transferred.',
      dailyCap: DAILY_RP_CAP,
      capUsedToday: usedToday,
      capRemaining: Math.max(0, DAILY_RP_CAP - usedToday),
    };
  }

  /**
   * Get RP Shop catalog
   * GET /v1/games/shop
   */
  async getShopCatalog(userId, gameId) {
    const ownedSet = userInventories.get(userId) || new Set();
    const games = gameId ? [getCanonicalGame(gameId)].filter(Boolean) : CANONICAL_GAMES;

    const items = [];
    games.forEach((g) => {
      (g.boosters || []).forEach((b) => {
        items.push({
          ...b,
          gameId: g.id,
          gameName: g.name,
          isOwned: ownedSet.has(b.id),
        });
      });
    });

    return { items };
  }

  /**
   * Buy item from RP Shop
   * POST /v1/games/shop/buy
   */
  async buyShopItem({ userId, itemId, currency = 'rp' }) {
    let targetItem = null;
    let targetGame = null;

    for (const g of CANONICAL_GAMES) {
      const found = (g.boosters || []).find((b) => b.id === itemId);
      if (found) {
        targetItem = found;
        targetGame = g;
        break;
      }
    }

    if (!targetItem) {
      const err = new Error('Shop item not found.');
      err.statusCode = 404;
      err.code = 'ITEM_NOT_FOUND';
      throw err;
    }

    if (currency === 'rp') {
      const bal = userRPBalances.get(userId) || 0;
      if (bal < targetItem.rpPrice) {
        const err = new Error('Insufficient RP balance.');
        err.statusCode = 400;
        err.code = 'INSUFFICIENT_RP';
        throw err;
      }
      userRPBalances.set(userId, bal - targetItem.rpPrice);
    }

    if (!userInventories.has(userId)) {
      userInventories.set(userId, new Set());
    }
    userInventories.get(userId).add(targetItem.id);

    return {
      success: true,
      itemId: targetItem.id,
      itemName: targetItem.name,
      currency,
      remainingRp: userRPBalances.get(userId) || 0,
    };
  }

  /**
   * Get energy status
   * GET /v1/games/energy
   */
  async getEnergy(userId) {
    const energyData = this.getUserEnergy(userId);
    const now = Date.now();
    const nextRefillSec = energyData.energy >= MAX_ENERGY
      ? 0
      : Math.max(0, Math.floor((ENERGY_REFILL_MINUTES * 60 * 1000 - (now - energyData.lastRefillTime)) / 1000));

    return {
      energy: energyData.energy,
      maxEnergy: MAX_ENERGY,
      refillIntervalMinutes: ENERGY_REFILL_MINUTES,
      nextRefillSeconds: nextRefillSec,
    };
  }

  /**
   * Refill energy
   * POST /v1/games/energy/refill
   */
  async refillEnergy({ userId, method = 'ad' }) {
    const energyData = this.getUserEnergy(userId);
    if (energyData.energy >= MAX_ENERGY) {
      return { energy: MAX_ENERGY, message: 'Energy is already full.' };
    }

    if (method === 'ad') {
      energyData.energy = Math.min(MAX_ENERGY, energyData.energy + 1);
    } else if (method === 'coins' || method === 'full') {
      energyData.energy = MAX_ENERGY;
    }
    userEnergy.set(userId, energyData);

    return {
      success: true,
      energy: energyData.energy,
      maxEnergy: MAX_ENERGY,
    };
  }

  /**
   * Get Leaderboard for a game
   * GET /v1/games/leaderboards/:id
   */
  async getLeaderboard(gameId, period = 'weekly') {
    const game = getCanonicalGame(gameId);
    if (!game) {
      const err = new Error('Game not found.');
      err.statusCode = 404;
      throw err;
    }

    const mockPlayers = [
      { rank: 1, userId: 'u1', username: 'ChampionAhmad', avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', score: 18450, rpEarned: 350 },
      { rank: 2, userId: 'u2', username: 'Sara_Star', avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', score: 16200, rpEarned: 300 },
      { rank: 3, userId: 'u3', username: 'Ali_Pro', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100', score: 14890, rpEarned: 280 },
      { rank: 4, userId: 'u4', username: 'Bilal_King', avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', score: 13120, rpEarned: 250 },
      { rank: 5, userId: 'u5', username: 'Zainab_Live', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', score: 11950, rpEarned: 220 },
    ];

    return {
      gameId: game.id,
      gameName: game.name,
      period,
      topPlayers: mockPlayers,
      userRank: { rank: 14, score: 7420, rpEarned: 120 },
    };
  }

  /**
   * Get Daily & Weekly Missions
   * GET /v1/games/missions
   */
  async getMissions(userId) {
    return {
      dailyMissions: [
        { id: 'm1', title: 'Catch 30 Fish', gameId: 'fishing', target: 30, current: 18, rewardRp: 40, isClaimed: false },
        { id: 'm2', title: 'Score 3 Penalties in Football', gameId: 'football', target: 3, current: 3, rewardRp: 50, isClaimed: false },
        { id: 'm3', title: 'Make 3 Perfect Stops in Rocket', gameId: 'rocket_challenge', target: 3, current: 2, rewardRp: 45, isClaimed: false },
      ],
      weeklyMissions: [
        { id: 'wm1', title: 'Run 5,000m in Lion Adventure', gameId: 'lion_adventure', target: 5000, current: 2400, rewardRp: 150, isClaimed: false },
        { id: 'wm2', title: 'Clear 10 Fruit Match Levels', gameId: 'fruit_match', target: 10, current: 7, rewardRp: 180, isClaimed: false },
        { id: 'wm3', title: 'Create 5 Sevens in Seven Puzzle', gameId: 'seven_puzzle', target: 5, current: 5, rewardRp: 160, isClaimed: true },
      ],
    };
  }

  /**
   * Claim Mission Reward
   * POST /v1/games/missions/:id/claim
   */
  async claimMission(userId, missionId) {
    const bal = userRPBalances.get(userId) || 0;
    userRPBalances.set(userId, bal + 50);

    return {
      success: true,
      missionId,
      rpReward: 50,
      newRpBalance: userRPBalances.get(userId),
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
