"use server";

import { redirect } from "next/navigation";
import { getSiteUrl, getSupabasePublicConfig } from "@/lib/env";
import { getSafeInternalPath } from "@/lib/auth/redirects";
import { getAuthenticatedUser, getProfileRole } from "@/lib/auth/session";
import { hasActiveBrandMembership } from "@/lib/auth/brand-access";
import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

function getField(formData: FormData, name: string, shouldTrim = true) {
  const value = formData.get(name);
  if (typeof value !== "string") return "";
  return shouldTrim ? value.trim() : value;
}

async function safeRequest<T>(request: () => PromiseLike<T>): Promise<T | null> {
  try {
    return await request();
  } catch {
    return null;
  }
}

export async function signInAction(formData: FormData) {
  const email = getField(formData, "email").toLowerCase();
  const password = getField(formData, "password", false);
  const requestedNext = formData.get("next");

  if (!getSupabasePublicConfig()) redirect("/login?error=setup");
  if (!email || email.length > 254 || !password || password.length > 128) {
    redirect("/login?error=credentials");
  }

  const supabase = await createClient();
  const result = await safeRequest(() => supabase.auth.signInWithPassword({ email, password }));
  if (!result || result.error) redirect("/login?error=credentials");
  const userId = result.data.user.id;
  const role = await getProfileRole(userId);
  const hasBrandDraft = typeof result.data.user.user_metadata?.brand_name === "string";
  const defaultPath = role === "brand" && await hasActiveBrandMembership(userId) ? "/brand" : role === "admin" ? "/admin" : hasBrandDraft ? "/open-brand" : "/profile";
  const nextPath = getSafeInternalPath(requestedNext, defaultPath);
  redirect(nextPath);
}

export async function signUpAction(formData: FormData) {
  const fullName = getField(formData, "fullName");
  const email = getField(formData, "email").toLowerCase();
  const password = getField(formData, "password", false);
  const accountType = getField(formData, "accountType") || "user";
  const brandName = getField(formData, "brandName");
  const brandDescription = getField(formData, "brandDescription");
  const signupPath = accountType === "brand" ? "/register?account=brand&" : "/register?";

  if (!getSupabasePublicConfig()) redirect("/register?error=setup");
  if (!["user", "brand"].includes(accountType)
    || (accountType === "brand" && (brandName.length < 2 || brandName.length > 120 || brandDescription.length < 2 || brandDescription.length > 2000))) {
    redirect(`${signupPath}error=invalid-brand`);
  }
  if (!fullName || fullName.length > 80 || !email || email.length > 254 || password.length < 8 || password.length > 128) {
    redirect(`${signupPath}error=invalid-input`);
  }

  const supabase = await createClient();
  const result = await safeRequest(() => supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${getSiteUrl()}/auth/callback?next=${accountType === "brand" ? "/open-brand" : "/profile"}`,
        // Draft intent only. Role and membership are created by open_my_brand.
        data: { full_name: fullName, ...(accountType === "brand" ? { brand_name: brandName, brand_description: brandDescription } : {}) },
      },
    }));

  if (!result) redirect(`${signupPath}error=network`);
  if (result.error) {
    // Only expose allowlisted codes, never raw provider messages or user data.
    const code = result.error.code;
    const category = code === "over_email_send_rate_limit" || code === "over_request_rate_limit" ? "rate-limit"
      : code === "email_address_invalid" || code === "email_address_not_authorized" ? "email"
      : code === "weak_password" ? "password"
      : code === "signup_disabled" || code === "email_provider_disabled" ? "signup-disabled"
      : code === "user_already_exists" || code === "email_exists" ? "existing-account"
      : code === "unexpected_failure" ? "auth-service" : "signup";
    redirect(`${signupPath}error=${category}`);
  }
  // Supabase may obscure an existing account by returning no identities.
  if (result.data.user?.identities?.length === 0) redirect(`/login?message=existing-account${accountType === "brand" ? "&next=%2Fopen-brand" : ""}`);
  if (result.data.session) redirect(accountType === "brand" ? "/open-brand" : "/profile");
  redirect(accountType === "brand" ? "/login?message=check-email&next=%2Fopen-brand" : "/login?message=check-email");
}

export async function signOutAction() {
  if (getSupabasePublicConfig()) {
    const supabase = await createClient();
    const result = await safeRequest(() => supabase.auth.signOut());
    if (!result || result.error) redirect("/profile?error=logout");
  }

  redirect("/");
}

export async function updateProfileAction(formData: FormData) {
  const user = await getAuthenticatedUser();
  if (!user) redirect("/login?next=%2Fprofile");
  if (!getSupabasePublicConfig()) redirect("/profile?error=setup");

  const displayName = getField(formData, "displayName");
  if (!displayName || displayName.length > 80) {
    redirect("/profile?error=invalid-profile");
  }

  const supabase = await createClient();
  const result = await safeRequest(() => supabase
      .from("profiles")
      .update({ display_name: displayName })
      .eq("id", user.id)
      .select("id")
      .maybeSingle());

  if (!result || result.error || !result.data) redirect("/profile?error=profile-save");
  revalidatePath("/profile");
  redirect("/profile?message=profile-saved");
}
