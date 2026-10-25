import "server-only";

import { redirect } from "next/navigation";
import { getAuthenticatedUser, getProfileRole } from "@/lib/auth/session";
import { hasActiveBrandMembership } from "@/lib/auth/brand-access";

export async function requireAuthenticatedUser(nextPath = "/profile") {
  const user = await getAuthenticatedUser();

  if (!user) {
    const next = encodeURIComponent(nextPath);
    redirect(`/login?next=${next}`);
  }

  return user;
}

export async function requireRole(role: "brand" | "admin", nextPath: string) {
  const user = await requireAuthenticatedUser(nextPath);
  const profileRole = await getProfileRole(user.id);

  if (profileRole !== role || (role === "brand" && !await hasActiveBrandMembership(user.id))) {
    redirect(`/unauthorized?required=${role}`);
  }

  return user;
}
