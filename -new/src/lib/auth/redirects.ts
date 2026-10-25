export function getSafeInternalPath(value: FormDataEntryValue | string | null, fallback: string) {
  if (typeof value !== "string") return fallback;

  const path = value.trim();
  if (!path.startsWith("/") || path.startsWith("//") || path.includes("\\") || [...path].some(char => char.charCodeAt(0) <= 32 || char.charCodeAt(0) === 127)) {
    return fallback;
  }

  return path;
}
