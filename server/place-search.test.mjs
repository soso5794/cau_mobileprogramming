import test from 'node:test';
import assert from 'node:assert/strict';
import {createAiServer} from './index.mjs';
import {createPlaceSearch} from './place-search.mjs';
async function fixture(t, placeSearch) {
  const server = createAiServer({apiKey:'',placeSearch});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  t.after(()=>new Promise(r=>server.close(r)));
  const url=`http://127.0.0.1:${server.address().port}/api/places/search`;
  return {url,post:query=>fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({query})})};
}
test('place search independent of OpenAI, validates and normalizes provider results', async t=>{
  const search=createPlaceSearch({apiKey:'mock-key',fetchImpl:async url=>{
    assert.equal(url.origin,'https://api.geoapify.com');
    assert.equal(url.searchParams.get('text'),'중앙대학교');
    assert.equal(url.searchParams.get('filter'),'countrycode:kr');
    return Response.json({results:[{name:'중앙대학교',formatted:'서울 동작구 흑석로 84',lat:37.5,lon:126.95},{name:'bad',lat:999,lon:126}]});
  }});
  const {post}=await fixture(t,search);
  const res=await post('중앙대학교');assert.equal(res.status,200);
  assert.deepEqual(await res.json(),{results:[{name:'중앙대학교',address:'서울 동작구 흑석로 84',latitude:37.5,longitude:126.95}]});
  assert.equal((await post(' ')).status,400);
});
test('missing place key and CORS preflight',async t=>{
  const {url,post}=await fixture(t,createPlaceSearch({apiKey:'',fetchImpl:()=>assert.fail()}));
  assert.equal((await post('중앙대학교')).status,503);
  assert.equal((await fetch(url,{method:'OPTIONS',headers:{Origin:'http://localhost:1234'}})).status,204);
});
test('place provider error is not a fake result',async t=>{
  const {post}=await fixture(t,createPlaceSearch({apiKey:'mock',fetchImpl:async()=>new Response('',{status:429})}));
  assert.equal((await post('중앙대학교')).status,429);
});
