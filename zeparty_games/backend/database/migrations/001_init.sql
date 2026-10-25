-- ZeParty Games: initial schema
-- Users are owned by the ZeParty host application. This schema only stores game-side state
-- keyed by the host user id (text, opaque).

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Wallet: ledger first. The balance column is a cached projection of the ledger,
-- updated inside the same transaction that inserts the ledger row.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallets (
  wallet_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        TEXT NOT NULL,
  currency_type  TEXT NOT NULL DEFAULT 'ZCOIN',
  balance        BIGINT NOT NULL DEFAULT 0 CHECK (balance >= 0),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, currency_type)
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  transaction_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id        UUID NOT NULL REFERENCES wallets(wallet_id),
  user_id          TEXT NOT NULL,
  transaction_type TEXT NOT NULL,          -- reward_match, reward_achievement, reward_daily, reward_promo, purchase_cosmetic, admin_adjust
  amount           BIGINT NOT NULL,        -- signed, positive credit, negative debit
  balance_after    BIGINT NOT NULL,
  reference_id     TEXT,                   -- match id, achievement id, cosmetic id
  idempotency_key  TEXT NOT NULL,
  metadata         JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (wallet_id, idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_created ON wallet_transactions (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Cosmetics and inventory
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cosmetics (
  cosmetic_id   TEXT PRIMARY KEY,           -- e.g. ludo_royale.board.crystal_kingdom
  game_id       TEXT NOT NULL,              -- 'common' for cross-game items
  category      TEXT NOT NULL,              -- board, dice, token, cue, striker, frame, reaction, theme, effect
  name          TEXT NOT NULL,
  description   TEXT NOT NULL DEFAULT '',
  price         BIGINT NOT NULL CHECK (price >= 0),
  preview_asset TEXT,
  enabled       BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inventory_items (
  user_id      TEXT NOT NULL,
  cosmetic_id  TEXT NOT NULL REFERENCES cosmetics(cosmetic_id),
  acquired_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  source_tx    UUID REFERENCES wallet_transactions(transaction_id),
  PRIMARY KEY (user_id, cosmetic_id)
);

CREATE TABLE IF NOT EXISTS equipped_cosmetics (
  user_id     TEXT NOT NULL,
  game_id     TEXT NOT NULL,
  category    TEXT NOT NULL,
  cosmetic_id TEXT NOT NULL REFERENCES cosmetics(cosmetic_id),
  PRIMARY KEY (user_id, game_id, category)
);

-- ---------------------------------------------------------------------------
-- Matches and results
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS matches (
  match_id     TEXT PRIMARY KEY,
  room_id      TEXT NOT NULL,
  game_id      TEXT NOT NULL,
  ruleset      JSONB NOT NULL DEFAULT '{}'::jsonb,
  status       TEXT NOT NULL,                -- active, completed, abandoned
  started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at     TIMESTAMPTZ,
  final_state  JSONB,
  winner_ids   TEXT[] NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS match_participants (
  match_id   TEXT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL,
  seat       INT NOT NULL,
  placement  INT,                               -- 1 = winner
  score      BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (match_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_match_participants_user ON match_participants (user_id);

-- Event log for reconnection replay and audit. Sequence numbers are per match.
CREATE TABLE IF NOT EXISTS match_events (
  match_id   TEXT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
  seq        INT NOT NULL,
  actor_id   TEXT,
  event_type TEXT NOT NULL,
  payload    JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, seq)
);

-- ---------------------------------------------------------------------------
-- Achievements, leaderboards, admin config
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS achievements (
  achievement_id TEXT PRIMARY KEY,
  game_id        TEXT NOT NULL,
  name           TEXT NOT NULL,
  description    TEXT NOT NULL DEFAULT '',
  reward_coins   BIGINT NOT NULL DEFAULT 0,
  enabled        BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS user_achievements (
  user_id        TEXT NOT NULL,
  achievement_id TEXT NOT NULL REFERENCES achievements(achievement_id),
  unlocked_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  claimed_at     TIMESTAMPTZ,
  PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS leaderboard_entries (
  game_id   TEXT NOT NULL,
  period    TEXT NOT NULL,     -- alltime, weekly:YYYY-WW, daily:YYYY-MM-DD
  user_id   TEXT NOT NULL,
  wins      INT NOT NULL DEFAULT 0,
  matches   INT NOT NULL DEFAULT 0,
  score     BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (game_id, period, user_id)
);
CREATE INDEX IF NOT EXISTS idx_leaderboard_rank ON leaderboard_entries (game_id, period, score DESC);

CREATE TABLE IF NOT EXISTS game_config (
  game_id    TEXT PRIMARY KEY,
  config     JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_rewards (
  user_id    TEXT NOT NULL,
  reward_day DATE NOT NULL,
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, reward_day)
);
