import test from 'node:test';
import assert from 'node:assert/strict';
import {createPasswordReset, smtpMailer} from './password-reset.mjs';
import {createAiServer} from './index.mjs';
const email = 'member@example.com';
function fixture(sendOverride) {
  let clock = 1000000, mail;
  const service = createPasswordReset({now: () => clock, sendMail: sendOverride ?? (async (to, code) => {mail = {to, code};})});
  return {service, get mail() {return mail;}, advance(ms) {clock += ms;}};
}
const errorCode = code => e => e.message === code;
test('mail-only code is bound to email and request; replay is rejected', async () => {
  const f = fixture(), request = await f.service.request({email: ' MEMBER@example.com '});
  assert.equal(f.mail.to, email); assert.match(f.mail.code, /^\d{6}$/);
  assert.equal(JSON.stringify(request).includes('"code"'), false);
  const input = {email, challengeId: request.challengeId, code: f.mail.code};
  assert.throws(() => f.service.verify({...input, email: 'other@example.com'}));
  assert.throws(() => f.service.verify({...input, challengeId: 'wrong'}));
  assert.deepEqual(f.service.verify(input), {verified: true, email, challengeId: request.challengeId});
  assert.throws(() => f.service.verify(input), errorCode('RESET_INVALID_OR_EXPIRED'));
});
test('expiry and five wrong guesses invalidate a code', async () => {
  for (const mode of ['expiry', 'guesses']) {
    const f = fixture(), request = await f.service.request({email});
    const input = {email, challengeId: request.challengeId, code: f.mail.code};
    if (mode === 'expiry') f.advance(600000);
    else for (let i = 0; i < 5; i++) assert.throws(() => f.service.verify({...input, code: 'invalid'}));
    assert.throws(() => f.service.verify(input));
  }
});
test('resend invalidates old challenge and enforces cooldown/hourly limits', async () => {
  const f = fixture(), first = await f.service.request({email});
  const input = {email, challengeId: first.challengeId, code: f.mail.code};
  await assert.rejects(f.service.request({email}), errorCode('RESET_RATE_LIMITED'));
  f.advance(60000); await f.service.request({email});
  assert.throws(() => f.service.verify(input));
  for (let i = 0; i < 3; i++) {f.advance(60000); await f.service.request({email});}
  f.advance(60000); await assert.rejects(f.service.request({email}), errorCode('RESET_RATE_LIMITED'));
  f.advance(3600000); await f.service.request({email});
});
test('SMTP missing/failure never returns a challenge, and concurrent send is limited', async () => {
  assert.equal(smtpMailer({}), null);
  await assert.rejects(createPasswordReset({sendMail: null}).request({email}), errorCode('MAIL_NOT_CONFIGURED'));
  const bad = fixture(async () => {throw new Error('secret SMTP detail');});
  await assert.rejects(bad.service.request({email}), errorCode('MAIL_DELIVERY_FAILED'));
  let release;
  const pending = fixture(() => new Promise(resolve => {release = resolve;}));
  const first = pending.service.request({email});
  await assert.rejects(pending.service.request({email}), errorCode('RESET_RATE_LIMITED'));
  release(); await first;
});
test('aggregate send limit applies across different mailboxes', async () => {
  const f = fixture();
  for (let i = 0; i < 30; i++) await f.service.request({email: `m${i}@example.com`});
  await assert.rejects(f.service.request({email}), errorCode('RESET_RATE_LIMITED'));
});
test('HTTP request/verify work without OpenAI key, enforce CORS and hide codes', async t => {
  const f = fixture();
  const server = createAiServer({apiKey: '', passwordReset: f.service});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (path, data, origin = 'http://localhost:7363') => fetch(`${base}/api/password-reset/${path}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', Origin: origin}, body: JSON.stringify(data),
  });
  assert.equal((await post('request', {email}, 'https://attacker.example')).status, 403);
  const preflight = await fetch(`${base}/api/password-reset/request`, {method: 'OPTIONS', headers: {Origin: 'http://localhost:7363'}});
  assert.equal(preflight.status, 204);
  const request = await post('request', {email}); assert.equal(request.status, 200);
  const body = await request.json(); assert.equal(body.code, undefined);
  const verified = await post('verify', {email, challengeId: body.challengeId, code: f.mail.code});
  assert.equal(verified.status, 200); assert.equal((await verified.json()).verified, true);
  assert.equal((await post('verify', {email, challengeId: body.challengeId, code: f.mail.code})).status, 400);
});
