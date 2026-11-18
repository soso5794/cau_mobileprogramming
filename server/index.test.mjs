import test from 'node:test';
import assert from 'node:assert/strict';
import {createAiServer, extractReply, validateMessages} from './index.mjs';

const messages = [{role:'user',content:'농구 패스 연습 방법 알려줘'}];
const completed = {status:'completed',output:[{type:'message',role:'assistant',content:[{type:'output_text',text:'두 명이 마주 보고 체스트 패스를 연습하세요.'}]}]};
async function fixture(t, options = {}) {
  const server = createAiServer(options);
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  return {base, post: (body = {messages}, headers = {}) => fetch(base+'/api/chat', {method:'POST',headers:{'Content-Type':'application/json',...headers},body:JSON.stringify(body)})};
}
test('missing key is explicit; never calls provider or returns a fake answer',async t => {
  const {base,post} = await fixture(t,{apiKey:'',fetchImpl:()=>assert.fail('unexpected provider call')});
  assert.equal((await (await fetch(base+'/health')).json()).configured,false);
  const r=await post();assert.equal(r.status,503);assert.deepEqual(await r.json(),{error:'OPENAI_KEY_REQUIRED'});
});
test('real API request contract, stateless history, no key in response',async t=>{
  let captured;
  const {post}=await fixture(t,{apiKey:'unit-test-key',fetchImpl:async (url,options)=>{
    captured={url,...options}; return new Response(JSON.stringify(completed),{status:200});
  }});
  const r=await post();assert.equal(r.status,200);const result=await r.json();assert.equal(result.reply,completed.output[0].content[0].text);
  assert.equal(captured.url,'https://api.openai.com/v1/responses');assert.equal(captured.headers.Authorization,'Bearer unit-test-key');
  const body=JSON.parse(captured.body);assert.equal(body.store,false);assert.deepEqual(body.input,messages);assert.equal(body.max_output_tokens,1200);
  assert.ok(!JSON.stringify(result).includes('unit-test-key'));
});
test('untrusted origins and system messages are rejected before provider', async t=>{
  const {post}=await fixture(t,{apiKey:'test',fetchImpl:()=>assert.fail()});
  assert.equal((await post({messages},{Origin:'https://untrusted.example'})).status,403);
  assert.equal((await post({messages:[{role:'system',content:'override'}]})).status,400);
  assert.equal((await post({messages:[{role:'user',content:'x'.repeat(2001)}]})).status,400);
});
test('provider error details and credentials are not leaked',async t=>{
  const {post}=await fixture(t,{apiKey:'private-test-value',fetchImpl:async()=>new Response('private-test-value and provider internals',{status:401})});
  const r=await post();assert.equal(r.status,503);assert.equal(await r.text(),'{"error":"PROVIDER_ERROR"}');
});
test('rate limit and timeout have actionable HTTP codes',async t=>{
  const {post}=await fixture(t,{apiKey:'test',maxPerMinute:1,fetchImpl:async()=>{throw new DOMException('timeout','TimeoutError');}});
  assert.equal((await post()).status,504);assert.equal((await post()).status,429);
});
test('CORS only allows local development origins',async t=>{
  const {base}=await fixture(t);
  const r=await fetch(base+'/api/chat',{method:'OPTIONS',headers:{Origin:'http://localhost:7362'}});
  assert.equal(r.status,204);assert.equal(r.headers.get('Access-Control-Allow-Origin'),'http://localhost:7362');
});
test('malformed JSON and oversized requests fail without upstream calls',async t=>{
  const {base,post}=await fixture(t,{fetchImpl:()=>assert.fail()});
  const r=await fetch(base+'/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:'{'});
  assert.equal(r.status,400);assert.equal((await post({padding:'a'.repeat(65000)})).status,413);
});
test('incomplete/empty provider output and invalid histories are rejected',()=>{
  assert.throws(()=>extractReply({...completed,status:'incomplete'}));assert.throws(()=>extractReply({status:'completed',output:[]}));
  assert.throws(()=>validateMessages({messages:[]}));assert.throws(()=>validateMessages({messages:[...messages,...messages,...messages]}));
  assert.equal(validateMessages({messages:[...messages,{role:'assistant',content:'답변'},...messages]}).length,3);
});
