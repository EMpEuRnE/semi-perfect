/* global FormData */
import assert from 'node:assert/strict';
import console from 'node:console';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';

// Execute the actual server actions with explicit Auth/database doubles.
// This covers app branching, not Supabase Auth/email or browser integration.
function load(path, imports) {
 const code = ts.transpileModule(readFileSync(path, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
 const exports = {};
 runInNewContext(code, { exports, require: name => { if (!(name in imports)) throw new Error('Unexpected import: ' + name); return imports[name]; } });
 return exports;
}
const redirects = load('src/lib/auth/redirects.ts', {});
let state;
const reset = () => { state = { configured: true, role: 'user', active: false, session: true, user: { id: 'self' }, rpcError: null, rpcCalls: 0, signupCalls: 0 }; };
const redirect = path => { const error = new Error(path); error.redirect = path; throw error; };
const db = {
 auth: {
  async signUp(payload) { state.signupCalls++; state.signupPayload = payload; return { data: { session: state.session ? {} : null, user: state.signupUser }, error: state.authError }; },
  async signInWithPassword() { return { data: { user: state.user }, error: state.authError }; },
 },
 async rpc(name, args) { state.rpcCalls++; state.rpcName = name; state.rpcArgs = args; return { data: state.rpcError ? null : 'brand-id', error: state.rpcError }; },
};
const session = { getAuthenticatedUser: async () => state.user, getProfileRole: async () => state.role };
const brandAccess = { hasActiveBrandMembership: async () => state.active };
const guards = load('src/lib/auth/guards.ts', { 'server-only': {}, 'next/navigation': { redirect }, '@/lib/auth/session': session, '@/lib/auth/brand-access': brandAccess });
const imports = {
 'next/navigation': { redirect }, 'next/cache': { revalidatePath() {} },
 '@/lib/env': { getSiteUrl: () => 'https://demo.example', getSupabasePublicConfig: () => state.configured ? {} : null },
 '@/lib/auth/redirects': redirects, '@/lib/auth/session': session, '@/lib/auth/brand-access': brandAccess,
 '@/lib/supabase/server': { createClient: async () => db }, '@/lib/auth/guards': guards,
};
const auth = load('src/app/actions/auth.ts', imports);
const onboarding = load('src/app/actions/brand-onboarding.ts', imports);
const form = values => { const result = new FormData(); for (const [key, value] of Object.entries(values)) result.set(key, value); return result; };
const signup = { fullName: 'Owner', email: 'owner@example.test', password: 'DemoPassword123', accountType: 'brand', brandName: 'Demo Brand', brandDescription: 'Demo description' };
let count = 0;
async function goes(name, operation, target) {
 await assert.rejects(operation, error => error.redirect === target, name); console.log('OK', ++count, name);
}
reset();
await goes('brand signup with session continues to explicit enrollment', () => auth.signUpAction(form(signup)), '/open-brand');
assert.equal(state.signupPayload.options.data.role, undefined);
assert.ok(state.signupPayload.options.emailRedirectTo.endsWith('next=/open-brand'));
console.log('OK', ++count, 'signup metadata grants no role and preserves callback destination');
reset(); state.session = false;
await goes('email verification signup preserves enrollment destination', () => auth.signUpAction(form(signup)), '/login?message=check-email&next=%2Fopen-brand');
reset();
await goes('ordinary signup keeps user flow', () => auth.signUpAction(form({ ...signup, accountType: 'user' })), '/profile');
reset();
await goes('forged admin account type rejected', () => auth.signUpAction(form({ ...signup, accountType: 'admin' })), '/register?error=invalid-brand');
assert.equal(state.signupCalls, 0);
reset();
await goes('empty brand details rejected', () => auth.signUpAction(form({ ...signup, brandName: '' })), '/register?account=brand&error=invalid-brand');
reset(); state.authError = { message: 'Auth unavailable' };
await goes('signup auth failure reported', () => auth.signUpAction(form(signup)), '/register?account=brand&error=signup');
reset(); state.role = 'brand'; state.active = true;
await goes('brand login opens dashboard', () => auth.signInAction(form(signup)), '/brand');
reset();
await goes('ordinary login opens profile', () => auth.signInAction(form(signup)), '/profile');
reset(); state.role = 'brand';
await goes('brand role without active membership cannot enter', () => guards.requireRole('brand', '/brand'), '/unauthorized?required=brand');
reset(); state.active = true;
await goes('user role alone cannot enter brand area', () => guards.requireRole('brand', '/brand'), '/unauthorized?required=brand');
reset(); state.user = null;
await goes('anonymous enrollment requires login', () => onboarding.openBrandAction(form({})), '/login?next=%2Fopen-brand');
reset();
await goes('enrollment requires explicit confirmation', () => onboarding.openBrandAction(form(signup)), '/open-brand?error=input');
assert.equal(state.rpcCalls, 0);
reset();
await goes('confirmed enrollment calls backend and opens dashboard', () => onboarding.openBrandAction(form({ ...signup, confirmPrototype: 'yes', role: 'admin', userId: 'another-account' })), '/brand?success=1');
assert.equal(state.rpcName, 'open_my_brand');
assert.deepEqual(Object.keys(state.rpcArgs).sort(), ['p_description', 'p_name']);
console.log('OK', ++count, 'server forwards no role or target account to RPC');
reset(); state.rpcError = { code: 'PGRST202' };
await goes('missing migration explained', () => onboarding.openBrandAction(form({ ...signup, confirmPrototype: 'yes' })), '/open-brand?error=migration');
reset(); state.rpcError = { code: '42501' };
await goes('suspended membership errors do not bypass backend', () => onboarding.openBrandAction(form({ ...signup, confirmPrototype: 'yes' })), '/open-brand?error=membership');
reset(); state.authError = { message: 'Invalid credentials' };
await goes('invalid password login rejected', () => auth.signInAction(form(signup)), '/login?error=credentials');
console.log(`Completed ${count} brand Auth/action checks with test doubles. Real Supabase Auth and browser flows are not covered.`);

for (const [code, category] of Object.entries({over_email_send_rate_limit: 'rate-limit', weak_password: 'password', signup_disabled: 'signup-disabled', email_address_invalid: 'email', unexpected_failure: 'auth-service'})) {
 reset(); state.authError = {code, message: 'private provider detail'};
 await goes(`safe signup error ${code}`, () => auth.signUpAction(form(signup)), `/register?account=brand&error=${category}`);
}
reset(); state.user.user_metadata = {brand_name: 'Draft Brand', role: 'admin'};
await goes('draft brand login resumes onboarding without granting privileges', () => auth.signInAction(form(signup)), '/open-brand');
reset(); state.signupUser = {identities: []};
await goes('existing signup points to login and preserves enrollment', () => auth.signUpAction(form(signup)), '/login?message=existing-account&next=%2Fopen-brand');
