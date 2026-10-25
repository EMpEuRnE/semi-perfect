import "server-only";

import { getSupabasePublicConfig } from "@/lib/env";
import { isAppRole, type AppRole } from "@/lib/auth/roles";
import { createClient } from "@/lib/supabase/server";

export type AuthenticatedUser = {
  id: string;
  email: string | null;
};

export type UserProfile = AuthenticatedUser & {
  displayName: string | null;
  avatarUrl: string | null;
  role: AppRole;
  createdAt: string;
};

export async function getAuthenticatedUser(): Promise<AuthenticatedUser | null> {
  if (!getSupabasePublicConfig()) return null;

  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims().catch(() => ({data: null, error: true}));
  const subject = data?.claims?.sub;

  if (error || !data || typeof subject !== "string") return null;

  return {
    id: subject,
    email: typeof data.claims.email === "string" ? data.claims.email : null,
  };
}

export async function getUserProfile(userId?: string): Promise<UserProfile | null> {
  if (!getSupabasePublicConfig()) return null;

  const user = userId ? null : await getAuthenticatedUser();
  const id = userId ?? user?.id;
  if (!id) return null;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id, display_name, avatar_url, role, created_at")
    .eq("id", id)
    .maybeSingle();

  if (error || !data || !isAppRole(data.role)) return null;

  return {
    id: data.id,
    email: user?.email ?? null,
    displayName: data.display_name,
    avatarUrl: data.avatar_url,
    role: data.role,
    createdAt: data.created_at,
  };
}

export async function getProfileRole(userId: string): Promise<AppRole | null> {
  const profile = await getUserProfile(userId);
  return profile?.role ?? null;
}
