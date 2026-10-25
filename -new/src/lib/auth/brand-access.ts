import "server-only";
import { createClient } from "@/lib/supabase/server";

export async function hasActiveBrandMembership(userId: string): Promise<boolean> {
  const db = await createClient();
  const { data, error } = await db.from("brand_memberships")
    .select("id, brands!inner(status)")
    .eq("profile_id", userId).eq("status", "active").eq("brands.status", "active").limit(1);
  return !error && Boolean(data?.length);
}
