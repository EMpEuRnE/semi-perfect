import process from 'node:process';
/* global fetch, FormData, URL */
import assert from 'node:assert/strict';
import console from 'node:console';
const base=process.env.TEST_BASE_URL || 'http://127.0.0.1:3000';
const guarded=['/progress','/open-brand','/profile','/wallet','/history','/brand','/brand/campaigns','/brand/challenges','/brand/analytics','/admin'];
for(const route of ['/','/login','/register','/missions','/rewards','/challenges',...guarded,'/auth/callback']){
 const r=await fetch(base+route,{redirect:'manual'});
 if(guarded.includes(route)){if(r.status===307) assert.ok(r.headers.get('location').startsWith('/login?next=')); else {assert.equal(r.status,200); const html=await r.text();assert.ok(html.includes('NEXT_REDIRECT') && html.includes('/login?next='));}}
 else if(route==='/auth/callback'){assert.equal(r.status,307);assert.equal(new URL(r.headers.get('location')).pathname+new URL(r.headers.get('location')).search,'/login?error=setup');}
 else assert.equal(r.status,200);
 console.log('OK',route,r.status);
}
for(const mode of ['login','register']){
 const page=await (await fetch(base+'/'+mode)).text();
 const action=page.match(/name="(\$ACTION_ID_[^"]+)"/);
 assert.ok(action,'server action form exists');
 const form=new FormData();form.set(action[1],'');form.set('email','demo@example.test');form.set('password','DemoOnly12345');form.set('fullName','Demo');
 const r=await fetch(base+'/'+mode,{method:'POST',body:form,redirect:'manual',headers:{origin:base}});
 assert.equal(r.status,303);assert.equal(r.headers.get('location'),'/'+mode+'?error=setup');
 console.log('OK',mode,'server action safely rejects missing setup');
}
const brandRegister=await (await fetch(base+'/register?account=brand')).text();
assert.ok(brandRegister.includes('name="brandName"') && brandRegister.includes('name="brandDescription"'));
console.log('OK brand registration exposes name and description');
assert.ok(brandRegister.includes('name="accountType" value="brand"'));
console.log('OK brand registration submits brand intent');
const userRegister=await (await fetch(base+'/register')).text();
assert.ok(userRegister.includes('name="accountType" value="user"') && !userRegister.includes('name="brandName"'));
console.log('OK ordinary registration remains separate');
console.log('22 HTTP checks completed without Supabase configuration. Auth success and signed-in UI are not covered.');
