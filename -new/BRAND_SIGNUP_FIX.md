# Brand signup fix

Branch: fix/brand-signup

## Confirmed findings
- Signup discarded all provider error codes and showed one generic error.
- A brand draft signing in without a next parameter defaulted to the user profile.
- Existing-account responses could incorrectly claim a verification email was sent.

## Changes
- Allowlisted signup error categories, no raw provider error or credentials displayed.
- Draft brand metadata routes login to explicit onboarding; it grants no authorization.
- Existing account responses route to login with brand enrollment destination.
- Clarified confirmation and callback recovery instructions; existing pending buttons retained.

## Database
No new migration. Existing 202610250006_brand_onboarding.sql remains required. No live data was modified. Backend enrollment and RLS remain authoritative.

## Validation
Lint, typecheck, 112 unit/action assertions passed. 151 embedded PostgreSQL assertions and legacy upgrade checks passed. Action tests use doubles; database tests simulate auth.uid().
Real signup, email delivery/confirmation, signed-in browser flow and two live brand accounts have not been tested. The original reported signup failure cannot be attributed to a specific provider error without reproducing it.

## Try on Windows
Stop dev server with Ctrl+C. Extract this ZIP in a new directory, then run START.cmd. Keep your old project as backup. This package includes the previously authorized local configuration; do not upload .env.local to GitHub.
Open /register?account=brand, submit once, and report the displayed error if unsuccessful. For an existing account, log in and use /open-brand.

## Supabase owner checks if needed
Authentication URL configuration must permit http://localhost:3000/auth/callback (and your actual deployed origin). Use the latest email link in the signup browser for the PKCE exchange. Auth logs are needed for auth-service errors; SMTP/rate limits need project-owner inspection. Do not disable verification or change database roles as a workaround.
