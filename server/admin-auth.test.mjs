import test from 'node:test';
import assert from 'node:assert/strict';
import {createAdminAuth,hashOperatorPassword,operatorEmail} from './admin-auth.mjs';
import {createAiServer} from './index.mjs';
const password = 'test-only-not-real-operator-password';
const account = await hashOperatorPassword(password);
test('operator has no demo bypass; wrong password fails and token is one session', async () => {
  const auth=createAdminAuth({account});
  await assert.rejects(auth.login({email:operatorEmail,password:'wrong-password'}));
  const login=await auth.login({email:operatorEmail,password});
  assert.match(login.token,/^[a-f0-9]{64}$/);
  assert.deepEqual(auth.verify(login.token),{authorized:true,email:operatorEmail});
  assert.throws(()=>auth.verify('forged-token'));
  auth.logout(login.token);assert.throws(()=>auth.verify(login.token));
  assert.equal(JSON.stringify(account).includes(password),false);
});
test('operator expires, fails closed without config, and rate limits guessing', async () => {
  let time=0;
  const auth=createAdminAuth({account,now:()=>time});
  const login=await auth.login({email:operatorEmail,password});
  time=28800000;assert.throws(()=>auth.verify(login.token));
  const absent=createAdminAuth({account:null});
  await assert.rejects(absent.login({email:operatorEmail,password}),e=>e.status===503);
  for(let i=0;i<10;i++) await assert.rejects(auth.login({email:operatorEmail,password:'no'}));
  await assert.rejects(auth.login({email:operatorEmail,password}),e=>e.status===429);
});
test('HTTP operator endpoints require real token and revoke it; no password leakage', async t=>{
  const server=createAiServer({adminAuth:createAdminAuth({account})});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base=`http://127.0.0.1:${server.address().port}`;
  const post=(route,body={},token='')=>fetch(`${base}/api/admin/${route}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify(body)});
  assert.equal((await post('session')).status,401);
  const login=await(await post('login',{email:operatorEmail,password})).json();
  assert.equal(JSON.stringify(login).includes(password),false);
  assert.equal((await post('session',{},login.token)).status,200);
  assert.equal((await post('logout',{},login.token)).status,200);
  assert.equal((await post('session',{},login.token)).status,401);
});
