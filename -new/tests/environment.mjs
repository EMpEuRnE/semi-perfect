import { Buffer } from 'node:buffer';
import process from 'node:process';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import console from 'node:console';
import ts from 'typescript';
const original={...process.env};
const js=ts.transpileModule(readFileSync('src/lib/env.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2020}}).outputText;
const {getSupabasePublicConfig}=await import('data:text/javascript;base64,'+Buffer.from(js).toString('base64'));
const jwt=role=>'eyJhbGciOiJIUzI1NiJ9.'+Buffer.from(JSON.stringify({role})).toString('base64url')+'.signature';
try {
 delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
 process.env.NEXT_PUBLIC_SUPABASE_URL='https://example.supabase.co';
 for(const key of ['sb_secret_example',jwt('service_role'),jwt('authenticated'),'invalid']) {
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=key;
  assert.equal(getSupabasePublicConfig(),null);
 }
 for(const key of ['sb_publishable_example',jwt('anon')]) {
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=key;
  assert.ok(getSupabasePublicConfig());
 }
 for(const url of ['http://example.supabase.co','ftp://localhost','https://name:password@example.test','invalid']) {
  process.env.NEXT_PUBLIC_SUPABASE_URL=url;
  assert.equal(getSupabasePublicConfig(),null);
 }
 process.env.NEXT_PUBLIC_SUPABASE_URL='http://localhost:54321';
 assert.ok(getSupabasePublicConfig());
 delete process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
 process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY=jwt('anon');
 assert.ok(getSupabasePublicConfig());
 delete process.env.NEXT_PUBLIC_SUPABASE_URL;
 assert.equal(getSupabasePublicConfig(),null);
 console.log('13 environment validation assertions completed.');
} finally {
 for(const key of ['NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY','NEXT_PUBLIC_SUPABASE_ANON_KEY']) {
  if(original[key]===undefined) delete process.env[key]; else process.env[key]=original[key];
 }
}
