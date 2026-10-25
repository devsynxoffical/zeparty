import { z } from 'zod';

const schema = z.object({
  PORT: z.coerce.number().default(8080),
  LOG_LEVEL: z.string().default('info'),
  DATABASE_URL: z.string().optional().default(''),
  REDIS_URL: z.string().optional().default(''),
  AUTH_ADAPTER: z.enum(['mock', 'jwt']).default('mock'),
  JWT_SECRET: z.string().default('dev-only-change-me'),
  JWT_ISSUER: z.string().default('zeparty'),
  ADMIN_API_KEY: z.string().default('dev-admin-key'),
  DEFAULT_TURN_TIMEOUT_SECONDS: z.coerce.number().default(30),
  DISCONNECT_GRACE_SECONDS: z.coerce.number().default(60),
});

export type AppConfig = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return schema.parse(env);
}

export const config = loadConfig();
