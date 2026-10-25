/* global fetch */
import process from 'node:process';
import console from 'node:console';
import assert from 'node:assert/strict';
const base=process.env.TEST_BASE_URL??'http://127.0.0.1:3110';
let count=0;
for(const route of ['/','/missions','/rewards','/challenges','/login','/register']){
 const response=await fetch(base+route);assert.equal(response.status,200);const html=await response.text();
 console.log('OK',++count,route);
 if(route==='/missions'){assert.ok(html.includes('เดิน 3,000 ก้าว')&&html.includes('ออกกำลังกาย 15 นาที')&&html.includes('เดินหรือวิ่ง 2 กิโลเมตร'),'three real daily missions render');console.log('OK',++count,'three daily quests rendered from configured backend');}
}
for(const route of ['/progress','/profile','/wallet','/history','/brand','/brand/campaigns','/brand/challenges','/brand/analytics','/admin']){
 const response=await fetch(base+route,{redirect:'manual'});
 if(response.status===307)assert.ok(response.headers.get('location').startsWith('/login?next='));
 else{assert.equal(response.status,200);const html=await response.text();assert.ok(html.includes('NEXT_REDIRECT')&&html.includes('/login?next='));}
 console.log('OK',++count,'protected',route);
}
const callback=await fetch(base+'/auth/callback',{redirect:'manual'});assert.equal(callback.status,307);console.log('OK',++count,'callback rejects missing code');
console.log(`${count} read-only public/protection checks passed. No signup/email or signed-in flow was executed.`);
