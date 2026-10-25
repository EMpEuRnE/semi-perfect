import type { NextConfig } from "next";

// Public environment variables are embedded into client bundles by Next.js.
// Abort configuration loading before an accidentally privileged key is bundled.
for (const key of [process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY]) {
  if (!key) continue;
  let privileged = key.trim().startsWith("sb_secret_");
  if (key.includes(".")) {
    try {
      const payload = JSON.parse(Buffer.from(key.split(".")[1], "base64url").toString("utf8"));
      privileged ||= payload.role === "service_role";
    } catch { /* Runtime config validation rejects malformed keys. */ }
  }
  if (privileged) throw new Error("Privileged Supabase credentials cannot be used in NEXT_PUBLIC variables.");
}

const nextConfig: NextConfig = {
  reactStrictMode: true,
};

export default nextConfig;
