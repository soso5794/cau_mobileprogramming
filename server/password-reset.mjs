import {createHash, randomBytes, randomInt, timingSafeEqual} from 'node:crypto';
import nodemailer from 'nodemailer';

export class ResetError extends Error {
  constructor(status, code) { super(code); this.status = status; }
}

export function smtpMailer(env = process.env) {
  const configured = ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASSWORD', 'SMTP_FROM'].every(k => env[k]?.trim());
  if (!configured) return null;
  const port = Number(env.SMTP_PORT || 465);
  if (![465, 587].includes(port)) return null;
  const transport = nodemailer.createTransport({
    host: env.SMTP_HOST, port, secure: port === 465, requireTLS: true,
    auth: {user: env.SMTP_USER, pass: env.SMTP_PASSWORD},
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 15000,
    logger: false, debug: false,
  });
  return async (email, code) => {
    const result = await transport.sendMail({
      from: env.SMTP_FROM, to: {address: email},
      subject: '[운동 Assist] 비밀번호 재설정 인증번호',
      text: `인증번호: ${code}\n\n10분 안에 비밀번호 재설정 화면에 입력해주세요.\n본인이 요청하지 않았다면 이 메일을 무시하세요. 인증번호를 다른 사람에게 알려주지 마세요.`,
      disableFileAccess: true, disableUrlAccess: true,
    });
    if (!result.accepted?.length || result.rejected?.length) throw new Error('SMTP_REJECTED');
  };
}

// Verifies mailbox ownership only. Accounts/passwords remain on the device.
// No reset codes, passwords, mail credentials, or addresses are logged.
export function createPasswordReset({sendMail = smtpMailer(), now = Date.now} = {}) {
  const records = new Map();
  let globalStart = now(), globalRequests = 0;
  const hash = (id, code) => createHash('sha256').update(`${id}:${code}`).digest();
  const emailOf = data => {
    const email = typeof data?.email === 'string' ? data.email.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^\s@<>\r\n]+@[^\s@<>\r\n]+\.[^\s@<>\r\n]+$/.test(email) || email.endsWith('@demo.invalid')) {
      throw new ResetError(400, 'INVALID_EMAIL');
    }
    return email;
  };
  return {
    configured: Boolean(sendMail),
    async request(data) {
      const email = emailOf(data), time = now();
      if (!sendMail) throw new ResetError(503, 'MAIL_NOT_CONFIGURED');
      for (const [key, value] of records) {
        if (!value.pending && time - value.windowStart >= 3600000) records.delete(key);
      }
      if (time - globalStart >= 3600000) { globalStart = time; globalRequests = 0; }
      const old = records.get(email);
      if (globalRequests >= 30 || (old && (old.pending || time - old.sentAt < 60000 || old.requests >= 5 || old.failures >= 20))) {
        throw new ResetError(429, 'RESET_RATE_LIMITED');
      }
      // Reserve limits before awaiting SMTP, also invalidate any earlier code.
      const record = {
        windowStart: old?.windowStart ?? time, requests: (old?.requests ?? 0) + 1,
        failures: old?.failures ?? 0, sentAt: time, pending: true, attempts: 0,
      };
      records.set(email, record); globalRequests++;
      const challengeId = randomBytes(32).toString('hex');
      const code = String(randomInt(0, 1000000)).padStart(6, '0');
      try {
        await sendMail(email, code);
        record.id = challengeId;
        record.digest = hash(challengeId, code);
        record.expiresAt = now() + 600000;
        return {challengeId, expiresInSeconds: 600, retryAfterSeconds: 60};
      } catch {
        throw new ResetError(502, 'MAIL_DELIVERY_FAILED');
      } finally { record.pending = false; }
    },
    verify(data) {
      const email = emailOf(data), record = records.get(email);
      if (!record || record.pending || !record.digest || record.expiresAt <= now() || record.attempts >= 5 || record.failures >= 20) {
        throw new ResetError(400, 'RESET_INVALID_OR_EXPIRED');
      }
      record.attempts++; record.failures++;
      if (data.challengeId !== record.id || typeof data.code !== 'string' || !/^\d{6}$/.test(data.code) || !timingSafeEqual(hash(record.id, data.code), record.digest)) {
        throw new ResetError(400, 'RESET_INVALID_OR_EXPIRED');
      }
      // Consume synchronously: concurrent/replayed verification cannot succeed.
      delete record.digest;
      return {verified: true, email, challengeId: record.id};
    },
  };
}
