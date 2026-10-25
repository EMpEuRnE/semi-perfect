import { AppShell } from "@/components/layout/app-shell";
import { requireRole } from "@/lib/auth/guards";

export const dynamic = "force-dynamic";

export default async function BrandLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  await requireRole("brand", "/brand");
  return <AppShell role="brand">{children}</AppShell>;
}
