import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { getSupabasePublicConfig } from "@/lib/env";

export async function updateSession(request: NextRequest) {
  const config = getSupabasePublicConfig();

  if (!config) return NextResponse.next({ request });

  let response = NextResponse.next({ request });
  const supabase = createServerClient(config.url, config.publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }

        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  // Refresh and verify the cookie-backed session. Authorization is checked
  // separately in server-side route guards and database RLS policies.
  try {
    await supabase.auth.getClaims();
  } catch {
    // Preserve public navigation during Auth outages. Protected pages/actions
    // independently verify identity and fail closed through their guards.
  }

  return response;
}
