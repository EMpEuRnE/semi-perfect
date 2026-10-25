import { AppShell } from "@/components/layout/app-shell";
import { requireRole } from "@/lib/auth/guards";

export const dynamic = "force-dynamic";

export default async function AdminLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  await requireRole("admin", "/admin");
  return <AppShell role="admin">{children}</AppShell>;
}
