import test from 'node:test';
import assert from 'node:assert/strict';
import {createAiServer, validateRecruitment, extractRecruitment} from './index.mjs';
const input={sport:'런닝',start:'2026-12-20T19:00:00.000',end:'2026-12-20T20:00:00.000',place:'중앙공원',minPeople:2,maxPeople:6,intensity:'보통',fields:{'목표 거리':'5km'},details:'러닝화 필수',allowMerge:true};
const draft={title:'5km 러닝 모집',body:'중앙공원에서 함께 달려요.',conditions:['러닝화 필수']};
const completed={status:'completed',output:[{type:'message',role:'assistant',content:[{type:'output_text',text:JSON.stringify(draft)}]}]};
async function fixture(t,opts={}){
 const server=createAiServer(opts);await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));
 const url=`http://127.0.0.1:${server.address().port}/api/recruitment/generate`;
 return {url,post:(data=input)=>fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})};
}
test('recruitment sends structured JSON schema and preserves chat model independence',async t=>{
 let captured;const {post}=await fixture(t,{apiKey:'test',recruitmentModel:'recruitment-model',fetchImpl:async(_,opts)=>{captured=JSON.parse(opts.body);return new Response(JSON.stringify(completed));}});
 const r=await post();assert.equal(r.status,200);assert.deepEqual(await r.json(),{...draft,model:'recruitment-model'});
 assert.equal(captured.model,'recruitment-model');assert.equal(captured.store,false);assert.equal(captured.text.format.strict,true);assert.deepEqual(JSON.parse(captured.input[0].content),input);
});
test('missing key is explicit, no fake AI output',async t=>{const {post}=await fixture(t,{apiKey:'',fetchImpl:()=>assert.fail()});assert.equal((await post()).status,503);});
test('invalid recruitment input is rejected before provider',async t=>{const {post}=await fixture(t,{apiKey:'test',fetchImpl:()=>assert.fail()});for(const change of [{minPeople:7},{end:input.start},{place:''},{allowMerge:'true'},{fields:[]},{start:'2026-02-30T19:00:00.000'}])assert.equal((await post({...input,...change})).status,400);});
test('malformed provider draft rejected',async t=>{const {post}=await fixture(t,{apiKey:'test',fetchImpl:async()=>new Response(JSON.stringify({...completed,output:[]}))});assert.equal((await post()).status,502);});
test('recruitment supports browser preflight',async t=>{const {url}=await fixture(t);const r=await fetch(url,{method:'OPTIONS',headers:{Origin:'http://localhost:1234'}});assert.equal(r.status,204);assert.equal(r.headers.get('access-control-allow-origin'),'http://localhost:1234');});
test('unknown fields discarded; conditions validated',()=>{assert.equal(validateRecruitment({...input,tier:'gold'}).tier,undefined);assert.deepEqual(extractRecruitment(completed),draft);assert.throws(()=>extractRecruitment({...completed,status:'incomplete'}));});
