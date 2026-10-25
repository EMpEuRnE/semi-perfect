# Move & Earn — phased technical review and handoff

Reviewed: 25 October 2026 (Asia/Bangkok).
Baseline: existing Move-and-Earn.zip. The workspace was empty; the existing archive was recovered rather than rebuilding the app. The archive has no .git directory, so Git status, branches and prior commits are unavailable. No new Git history was invented.

## Overall status

The existing full-stack MVP has been retained and hardened. It compiles and passes local regression checks. It is NOT yet a verified competition demo: live database connection, real Auth accounts, signed-in browser testing, concurrency testing and deployment remain pending. Database connection was explicitly deferred by the user. No remote database was changed.

## 1. Inspection — existing architecture

- Next.js 16 App Router, React 19, strict TypeScript, Tailwind 4 through @tailwindcss/postcss, Lucide icons. Exact versions are pinned by pnpm-lock.yaml; Node >=22 and pnpm 11.25.0.
- src/app/(user): home, login/register, mission list/detail, challenges, rewards, wallet, profile and history.
- src/app/brand: dashboard, campaigns, challenges, create-challenge and analytics. These routes intentionally share BrandDashboard; they are not separate purpose-built dashboards yet.
- src/app/admin: internal evidence review. src/app/auth/callback: Auth code exchange.
- src/app/actions: Auth, missions, challenges, rewards and brand Server Actions.
- src/lib/supabase: separate browser, server and proxy clients; cookie-backed SSR. src/proxy.ts refreshes sessions. Guards check authenticated identity and role server-side.
- src/components: shared layout/navigation, reusable buttons/cards/loading/notices, Auth and mission forms.
- Supabase PostgreSQL migrations contain the core entities, ledger, RLS, secure RPC workflows and reporting views. brands and brand_memberships supplement the requested ten tables to implement tenant membership.
- Wallet balances come from ledger aggregation. Critical business mutations run in transactional database functions, not browser state.
- .env.example documents browser-safe settings; no .env.local was configured. The Singapore region must be selected when the actual Supabase project is connected; source code cannot select a hosted project's region.
- next.config.ts uses React strict mode and rejects privileged Supabase keys in public variables. Production build uses webpack. tsconfig.json uses strict mode, bundler resolution and @/* alias. Tailwind 4 uses globals.css; no legacy tailwind.config.js is required.
- Tests: redirect/environment unit tests, embedded PostgreSQL integration tests and production HTTP checks. No real Supabase/browser integration suite exists yet.

Reuse the current app, clients, RLS, ledger, RPCs, guards and responsive shell. Avoid a backend rewrite, a second API layer, a duplicate balance table or a new frontend framework. Keep database authorization authoritative even when server guards have passed.

## 2. Foundation — completed locally

Retained architecture, route groups, reusable UI and browser/server client split. Removed project-specific values from .env.example. Public config rejects secret keys, service-role JWTs, malformed legacy tokens and unsafe URLs. Next configuration aborts before bundling an accidentally privileged public key. Session refresh network failures no longer crash public navigation; protected routes independently verify identity and fail closed. Added shared error boundary and Brand/Reward loading states.

## 3. Database — implemented and validated locally

Ten chronological migrations now exist. Existing eight were left intact. Added:

- 202610250004_idempotent_redemption.sql: per-user request IDs, unique index, replay-safe redemption under the existing wallet lock. Retries return the original record, including after refund; request reuse for another reward is rejected.
- 202610250005_nonnegative_adjustments.sql: Admin adjustments reject null amounts and negative resulting balances.

Core relationships: Auth user → profile → mission participation/activity → immutable point transaction; brand → campaign → challenge → participant/activity → completion credit; reward → redemption → debit/refund transactions.

All migrations and the seed ran against fresh PGlite PostgreSQL with simulated auth.uid(). This is meaningful SQL/RLS testing but does not verify Supabase Auth, PostgREST schema caches, network behavior, or multiple database connections.

Do not reset an existing Supabase database or replay applied migrations. Compare actual migration history and apply only missing files in chronological order. After applying new RPC signatures, verify PostgREST recognizes redeem_reward(p_reward_id, p_request_id).

## 4. Authentication and security — retained and strengthened

Login, registration, callback, logout and profile update exist. Roles are user/brand/admin. Users cannot self-assign elevated roles. There is no service-role client in the application.

Existing RLS policy groups (not newly recreated):

- profiles: own profile, plus Admin read; update grants only display_name/avatar_url.
- brands/memberships: public active brand discovery; member/Admin reads; manager updates.
- campaigns/challenges: public discovery for published records; private member scope; active manager inserts/updates.
- missions: public active discovery, participant access and Admin management.
- user_missions/participants: own participation and authorized reviewers/Admin.
- activities: own evidence and authorized reviewer visibility; submissions go through validated RPCs.
- point_transactions: owner/authorized campaign scope/Admin reads; no user write grant; append-only trigger.
- rewards: active discovery or own brand management.
- redemptions: owner or reward manager/Admin visibility; mutations through RPCs.
- user_point_balances: security-invoker aggregation. campaign_results: security-barrier aggregate with an explicit membership/Admin boundary.

SQL functions use explicit authorization and empty search_path. Wallet/profile and reward row locks serialize relevant operations. This design still needs real PostgreSQL concurrency verification. A newly generated request ID means a new intentional redemption; idempotency prevents replay of the same submitted form, not all repeat purchases.

## 5. Mission system — existing, regression checked

Start/join, evidence submission, pending/rejected/approved state, progress, completion and server-generated credits exist. Admin approves normal missions; Brand managers approve their sponsored challenges. Plan the demo with a second reviewer session: submission alone does not grant points. Duplicate approval, self-review, cross-user submission, zero/negative/NaN values and over-target submission are rejected in SQL tests.

Limitations: mission participation is one-time per mission definition, not a recurring daily schedule. No verified three-day streak algorithm is implemented. Evidence is a note/URL with manual review, not wearable data or fraud-proof activity measurement. Point values are prototype assumptions.

## 6. Wallet — existing, regression checked

Balance and transaction history derive from backend ledger data. Redemption debits and refunds are atomic. Added protection against Admin adjustments making the balance negative. No cash conversion, payment or withdrawal is provided.

## 7. Rewards — improved

Retained catalog and personal redemption records. Added category display, /rewards/[rewardId] detail pages, request IDs on forms, unavailable/expired detail state, empty redemption state and explicit internal-point/demo wording. Backend revalidates availability, price, stock and balance. Replay, refund replay, insufficient balance, stock and expiry assertions pass locally.

## 8. Brand — improved

Retained campaign/challenge creation, publication, evidence review, fulfillment/refund and analytics. Added detail editing and pause/resume publication, participant status/progress display and completion-rate/activity metrics. Campaign/challenge dashboard queries now explicitly filter to the current user's brand memberships, in addition to database RLS.

Brand routes still share one dashboard. Target/points are set during creation; this editing UI intentionally changes descriptive fields only. Budgets are placeholders and there is no real campaign billing. The demo demonstrates engagement metrics, not validated commercial demand or ROI.

## 9. UI — local changes, visual QA pending

Retained startup-style homepage, user/brand navigation and mobile shell. Improved form sizing, keyboard focus, touch targets, reduced-motion behavior and shared loading/error states. Chromium was unavailable; its download returned invalid/truncated archives. Desktop/mobile visual inspection and signed-in interactions could not be performed. HTTP checks are not a substitute for visual QA.

## 10. Demo preparation — next session

1. Extract this project and open its folder in VS Code. Use Node >=22. Run pnpm install --frozen-lockfile, then pnpm dev.
2. Without Supabase, public routes show setup/empty states and private routes redirect to login. This is not an offline functional demo and does not pretend to create points in localStorage.
3. Later create/connect a dedicated Supabase demo project in Singapore. Copy .env.example to .env.local and provide only the public project URL/key. Set NEXT_PUBLIC_SITE_URL and the Auth callback allowlist.
4. Compare migration history; apply pending migrations. Keep the remote project unchanged until this step.
5. Create User, Brand and Admin through Supabase Auth with actual passwords. For an email-free competition demo, pre-create confirmed accounts using the trusted Supabase dashboard. Use trusted SQL to set Brand/Admin roles and brand_memberships; never expose that capability through registration.
6. seed.sql inserts passwordless auth fixtures for embedded/local tests. They are not usable login accounts. Do not run this fixture seed against a production project. Prepare/reset demo content around the actual Auth user IDs rather than assuming fixture IDs authenticate.
7. User demo: login → mission → join → submit note/value → Admin approves in another session → wallet → reward → redemption → history. Use separate browser profiles for User/Admin/Brand.
8. Brand demo: login → create campaign → publish → create sponsored challenge → publish → User joins/submits → Brand approves → participants/results update → User redeems → Brand confirms simulated fulfillment.
9. Repeat with unrelated User/Brand accounts. Race two requests for low balance/last stock against real PostgreSQL. Verify one debit per request ID, no negative balance/stock and single refund restoration.
10. Deploy to Vercel, configure environment and Auth redirect URLs, and repeat the demo at the real URL. Deployment has not been performed.

## 11. Final QA results

- Frozen-lockfile install: PASS.
- ESLint: PASS.
- TypeScript: PASS.
- Production build: PASS.
- Redirect unit assertions: 10 PASS.
- Environment validation assertions: 13 PASS.
- Embedded database assertions: 42 PASS, all 10 migrations plus seed applied.
- Production HTTP checks without Supabase: 17 PASS; route access, callback and setup-failure server actions. Not authenticated E2E coverage.
- Real registration/login/session refresh/logout: NOT VERIFIED.
- Signed-in User and Brand browser flows: NOT VERIFIED.
- Live Supabase RLS/PostgREST: NOT VERIFIED.
- Real PostgreSQL concurrent requests: NOT VERIFIED.
- Desktop/mobile visual QA: BLOCKED by unavailable browser executable/download.
- Hosting/deployed URL: NOT CONFIGURED.

## Exact next phase

Connect the dedicated Supabase demo project and provision confirmed demo accounts, then run authenticated end-to-end checks. This is intentionally deferred per the user's instruction. Before competition submission, complete this phase plus concurrency, visual QA and deployment. Do not mark the application competition-ready solely because the local build and embedded tests pass.

See CHANGESET.txt for changed files. No secrets, installed dependencies, build outputs or fabricated commit history are included in the deliverable.
