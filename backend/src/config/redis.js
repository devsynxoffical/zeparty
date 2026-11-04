import { createClient } from 'redis';
import env from './env.js';

let redisClient = null;

export function getRedisClient() {
  if (!redisClient) {
    redisClient = createClient({
      url: env.REDIS_URL,
    });

    redisClient.on('error', (err) => {
      // Graceful error logging without crashing process
      if (env.NODE_ENV !== 'test') {
        console.warn('⚠️ Redis Connection Notice:', err.message);
      }
    });

    redisClient.on('connect', () => {
      console.log('🔌 Redis Client Connected');
    });
  }
  return redisClient;
}

export const redisProxy = new Proxy(
  {},
  {
    get(target, prop) {
      const client = getRedisClient();
      if (prop === 'isOpen') {
        return Boolean(client && client.isOpen);
      }
      const val = client[prop];
      if (typeof val === 'function') {
        return val.bind(client);
      }
      return val;
    },
  }
);

export default redisProxy;
