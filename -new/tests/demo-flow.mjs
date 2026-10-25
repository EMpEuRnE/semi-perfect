/* global FormData */
import assert from 'node:assert/strict';
import console from 'node:console';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import ts from 'typescript';
function load(path,imports){const exports={};const js=ts.transpileModule(readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;runInNewContext(js,{exports,require:key=>{if(!(key in imports))throw new Error(key);return imports[key];}});return exports;}
const snapshot={title:'Daily quest',target_value:3000,target_unit:'steps',points:30};
const tables={user_missions:[{id:'m1',mission_id:'m',user_id:'self',status:'joined',progress_value:0,participation_date:'2026-10-25',mission_snapshot:snapshot},{id:'m2',mission_id:'m',user_id:'self',status:'joined',progress_value:0,participation_date:'2026-10-24',mission_snapshot:snapshot},{id:'m3',mission_id:'m',user_id:'self',status:'completed',progress_value:3000,participation_date:'2026-10-23',mission_snapshot:snapshot}],challenge_participants:[{id:'cp',challenge_id:'c',user_id:'self',status:'in_progress',progress_value:1}],missions:[{id:'m',...snapshot,status:'active',ends_at:null}],challenges:[{id:'c',title:'Challenge',target_value:2,target_unit:'km',reward_points:60,status:'paused',ends_at:null}],mission_activity_totals:[{user_mission_id:'m1',pending_value:3000}],activities:[{user_id:'self',user_mission_id:null,challenge_participant_id:'cp',verification_status:'pending',value:1,reviewer_note:null}]};
let broken=false,rpcCalls=0,args;
const db={from(table){let rows=[...tables[table]];const q={select(){return q;},eq(k,v){rows=rows.filter(r=>r[k]===v);return q;},in(k,v){rows=rows.filter(r=>v.includes(r[k]));return q;},order(){return q;},limit(n){rows=rows.slice(0,n);return q;},then(resolve,reject){return Promise.resolve({data:rows,error:broken?{}:null}).then(resolve,reject);}};return q;},async rpc(name,payload){rpcCalls++;args=payload;return {error:null};}};
const progress=load('src/lib/progress.ts',{'server-only':{},'@/lib/supabase/server':{createClient:async()=>db},'@/lib/mission-rounds':{bangkokDay:()=> '2026-10-25'}});
let count=0;const ok=(name,value)=>{assert.ok(value,name);console.log('OK',++count,name);};
const state=await progress.getProgressData('self');
ok('progress loads mission rounds and challenges',state.status==='ready'&&state.data.length===4);
ok('pending mission progress remains zero',state.data.find(i=>i.id==='m1').state==='pending'&&state.data.find(i=>i.id==='m1').approved===0);
ok('previous unfinished day is closed',state.data.find(i=>i.id==='m2').state==='closed');
ok('approved completion distinct from pending',state.data.find(i=>i.id==='m3').state==='completed');
ok('paused challenge still shows pending submission',state.data.find(i=>i.id==='cp').state==='pending'&&state.data.find(i=>i.id==='cp').pending===1);
ok('historical round links to exact day',state.data.find(i=>i.id==='m2').href.endsWith('?day=2026-10-24'));
broken=true;ok('data errors produce error state',(await progress.getProgressData('self')).status==='error');broken=false;
const redirect=path=>{const error=new Error(path);error.redirect=path;throw error;};
const rewards=load('src/app/actions/rewards.ts',{'next/navigation':{redirect},'next/cache':{revalidatePath(){}},'@/lib/auth/guards':{requireAuthenticatedUser:async()=>({id:'self'}),requireRole:async()=>({id:'self'})},'@/lib/supabase/server':{createClient:async()=>db}});
const f=new FormData();f.set('rewardId','60000000-0000-4000-8000-000000000001');f.set('requestId','70000000-0000-4000-8000-000000000001');
await assert.rejects(()=>rewards.redeemRewardAction(f),e=>e.redirect==='/rewards?error=confirm');ok('unconfirmed redemption never reaches backend',rpcCalls===0);
f.set('confirmRedeem','yes');f.set('price','0');
await assert.rejects(()=>rewards.redeemRewardAction(f),e=>e.redirect==='/rewards?success=1');ok('confirmed redemption reaches atomic backend',rpcCalls===1);ok('client price is not forwarded',Object.keys(args).sort().join(',')==='p_request_id,p_reward_id');
console.log(`Completed ${count} progress and redemption action checks with database doubles.`);
