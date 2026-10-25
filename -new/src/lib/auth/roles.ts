export type AppRole = "user" | "brand" | "admin";

export function isAppRole(role: unknown): role is AppRole {
  return role === "user" || role === "brand" || role === "admin";
}
