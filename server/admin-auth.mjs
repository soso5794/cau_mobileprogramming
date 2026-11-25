import {readFileSync} from 'node:fs';
import {randomBytes, scrypt, timingSafeEqual} from 'node:crypto';
import {promisify} from 'node:util';
const derive = promisify(scrypt);
export const operatorEmail = 'operator@exercise-assist.local';
export class AdminError extends Error {
  constructor(status, code) {super(code); this.status = status;}
}
export function loadOperator() {
  try {
    const account = JSON.parse(readFileSync(new URL('./.operator-account.json', import.meta.url), 'utf8'));
    return account.email === operatorEmail && /^[a-f0-9]{32}$/.test(account.salt) && /^[a-f0-9]{128}$/.test(account.hash) ? account : null;
  } catch {return null;}
}
export async function hashOperatorPassword(password) {
  const salt = randomBytes(16).toString('hex');
  return {email: operatorEmail, salt, hash: (await derive(password, salt, 64)).toString('hex')};
}
export function createAdminAuth({account = loadOperator(), now = Date.now} = {}) {
  const sessions = new Map();
  let started = now(), attempts = 0;
  const prune = () => {for (const [token, expiry] of sessions) if (expiry <= now()) sessions.delete(token);};
  return {
    configured: Boolean(account),
    async login(data) {
      if (!account) throw new AdminError(503, 'ADMIN_NOT_CONFIGURED');
      if (now() - started >= 900000) {started = now(); attempts = 0;}
      if (attempts >= 10) throw new AdminError(429, 'ADMIN_RATE_LIMITED');
      attempts++;
      if (typeof data?.password !== 'string' || data.password.length < 8 || data.password.length > 256) throw new AdminError(401, 'ADMIN_INVALID_CREDENTIALS');
      const candidate = await derive(data.password, account.salt, 64);
      if (data.email !== account.email || !timingSafeEqual(candidate, Buffer.from(account.hash, 'hex'))) throw new AdminError(401, 'ADMIN_INVALID_CREDENTIALS');
      prune();
      if (sessions.size >= 10) sessions.delete(sessions.keys().next().value);
      const token = randomBytes(32).toString('hex');
      sessions.set(token, now() + 8 * 3600000);
      return {token, email: account.email, expiresInSeconds: 28800};
    },
    verify(token) {
      prune();
      if (typeof token !== 'string' || !sessions.has(token)) throw new AdminError(401, 'ADMIN_SESSION_EXPIRED');
      return {authorized: true, email: account.email};
    },
    logout(token) {sessions.delete(token); return {ok: true};},
  };
}
