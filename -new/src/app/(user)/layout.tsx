import { AppShell } from "@/components/layout/app-shell";

export default function UserLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AppShell role="user">{children}</AppShell>;
}
