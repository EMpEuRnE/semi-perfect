/* global FormData */
import assert from 'node:assert/strict';
import console from 'node:console';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import ts from 'typescript';
function load(path,imports={}){
 const exports={};
 const code=ts.transpileModule(readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 runInNewContext(code,{exports,Error,require:name=>{if(!(name in imports))throw new Error('Unexpected import '+name);return imports[name];}});
 return exports;
}
const validation=load('src/lib/brand-validation.ts');
const form=values=>{const f=new FormData();for(const [k,v]of Object.entries(values))f.set(k,v);return f;};
const id='30000000-0000-4000-8000-000000000001';
const good={kind:'challenge',brandId:id,campaignId:id,title:'Challenge name',description:'Challenge description',missionTitle:'Walk a kilometre',terms:'Registered members only',evidenceInstructions:'Submit distance and evidence',requiresEvidence:'yes',activityType:'walk',targetUnit:'km',target:'1',points:'90',participantLimit:'',startsAt:'2026-12-01T09:30',endsAt:'2026-12-02T09:30',rewardId:''};
let count=0;
function ok(name,value){assert.ok(value,name);console.log('OK',++count,name);}
const parsed=validation.parseBrandFields(form(good),'challenge');
ok('Bangkok dates converted to explicit UTC',parsed.starts_at==='2026-12-01T02:30:00.000Z');
ok('blank capacity is unlimited',parsed.participant_limit===null);
ok('completion points and evidence preserved',parsed.reward_points===90&&parsed.requires_evidence);
ok('local date round-trip uses Bangkok',validation.localDate(parsed.starts_at)==='2026-12-01T09:30');
for(const [name,patch]of [
 ['reversed dates',{endsAt:'2026-11-30T09:30'}],['invalid calendar day',{startsAt:'2026-02-30T09:30'}],['missing date',{startsAt:''}],
 ['negative target',{target:'-1'}],['non-finite target',{target:'Infinity'}],['fractional points',{points:'1.5'}],['invalid unit pair',{targetUnit:'steps'}],
 ['fractional step target',{activityType:'steps',targetUnit:'steps',target:'1.5'}],['zero seats',{participantLimit:'0'}],['fractional seats',{participantLimit:'1.5'}],
 ['negative seats',{participantLimit:'-1'}],['invalid reward identifier',{rewardId:'not-a-uuid'}],['missing mission',{missionTitle:''}],['missing terms',{terms:''}],['missing evidence instructions',{evidenceInstructions:''}],
]){assert.throws(()=>validation.parseBrandFields(form({...good,...patch}),'challenge'));console.log('OK',++count,'reject '+name);}
let state;
const reset=()=>{state={allowed:true,error:null,calls:0};};
const redirect=path=>{const e=new Error(path);e.redirect=path;throw e;};
const db={from(table){state.table=table;return {insert(values){state.calls++;state.values=values;return chain;},update(values){state.calls++;state.values=values;return chain;}};}};
const chain={eq(k,v){state.filter=[k,v];return chain;},select(){return chain;},async single(){return {error:state.error};}};
const actions=load('src/app/actions/brand.ts',{
 'next/navigation':{redirect},'next/cache':{revalidatePath(){}},'@/lib/auth/guards':{async requireRole(){if(!state.allowed)redirect('/unauthorized');}},
 '@/lib/supabase/server':{async createClient(){return db;}},'@/lib/brand-validation':validation,
});
async function goes(name,operation,target){await assert.rejects(operation,e=>e.redirect===target);console.log('OK',++count,name);}
reset();await goes('create Challenge persists validated fields',()=>actions.saveBrandItemAction(form(good)),'/brand?success=1');
ok('new Challenge is owned and draft by database default',state.table==='challenges'&&state.values.brand_id===id&&state.values.campaign_id===id&&!('status'in state.values));
reset();await goes('edit ignores forged ownership',()=>actions.editBrandItemAction(form({...good,id,brandId:'forged',campaignId:'forged'})),'/brand?success=1');
ok('edit cannot move brand or campaign',!('brand_id'in state.values)&&!('campaign_id'in state.values));
reset();state.allowed=false;await goes('non-brand blocked before write',()=>actions.saveBrandItemAction(form(good)),'/unauthorized');ok('denied actor never writes',state.calls===0);
for(const status of ['active','paused']){reset();await goes('owner status request '+status,()=>actions.activateBrandItemAction(form({kind:'challenges',id,status})),'/brand?success=1');}
reset();await goes('completion requires explicit confirmation',()=>actions.activateBrandItemAction(form({kind:'challenges',id,status:'completed'})),'/brand?error=input');
reset();await goes('confirmed completion reaches database checks',()=>actions.activateBrandItemAction(form({kind:'challenges',id,status:'completed',confirmComplete:'yes'})),'/brand?success=1');
reset();state.error={code:'22023',message:'Challenge terms are locked after participation'};await goes('locked terms error is explained',()=>actions.editBrandItemAction(form({...good,id})),'/brand?error=locked');
reset();state.error={code:'42501',message:'RLS violation'};await goes('cross-brand denial remains an error',()=>actions.saveBrandItemAction(form(good)),'/brand?error=permission');
console.log(`Completed ${count} campaign validation/action checks. Database and Auth are test doubles for action checks.`);
