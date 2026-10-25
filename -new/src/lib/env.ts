export type SupabasePublicConfig = {
  url: string;
  publishableKey: string;
};

/**
 * Supports the current publishable key and the non-secret legacy anon key.
 * Secret/service-role keys must never be passed to browser clients.
 */
export function getSupabasePublicConfig(): SupabasePublicConfig | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const publishableKey = (
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  )?.trim();

  if (!url || !publishableKey) return null;

  // Fail closed before passing any privileged credential to an SSR/browser client.
  if (publishableKey.startsWith("sb_secret_")) return null;
  if (!publishableKey.startsWith("sb_publishable_")) {
    try {
      const payload = JSON.parse(atob(publishableKey.split(".")[1] ?? ""));
      if (payload.role !== "anon") return null;
    } catch {
      return null;
    }
  }

  try {
    const parsedUrl = new URL(url);
    const isLocalHost = ["localhost", "127.0.0.1", "[::1]"].includes(parsedUrl.hostname);
    if (parsedUrl.username || parsedUrl.password || (parsedUrl.protocol !== "https:" && !(isLocalHost && parsedUrl.protocol === "http:"))) {
      return null;
    }
  } catch {
    return null;
  }

  return { url, publishableKey };
}

export function getSiteUrl() {
  const configuredUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  return (configuredUrl || "http://localhost:3000").replace(/\/$/, "");
}
