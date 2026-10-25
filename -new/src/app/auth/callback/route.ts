import { NextResponse, type NextRequest } from "next/server";
import { getSafeInternalPath } from "@/lib/auth/redirects";
import { getSupabasePublicConfig } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const nextPath = getSafeInternalPath(requestUrl.searchParams.get("next"), "/profile");

  if (!getSupabasePublicConfig()) {
    return NextResponse.redirect(new URL("/login?error=setup", request.url));
  }

  const code = requestUrl.searchParams.get("code");
  if (!code) {
    return NextResponse.redirect(new URL("/login?error=auth-callback", request.url));
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(new URL("/login?error=auth-callback", request.url));
  }

  return NextResponse.redirect(new URL(nextPath, request.url));
}
