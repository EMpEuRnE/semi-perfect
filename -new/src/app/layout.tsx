import type { Metadata, Viewport } from "next";
import "@/app/globals.css";

export const metadata: Metadata = {
  title: {
    default: "Move & Earn — ขยับเพื่อรับสิ่งดี ๆ",
    template: "%s | Move & Earn",
  },
  description: "ทำภารกิจที่ดีต่อสุขภาพ สะสมแต้ม และแลกรับรางวัลจากแบรนด์",
};

export const viewport: Viewport = {
  themeColor: "#f7f9f6",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="th">
      <body>{children}</body>
    </html>
  );
}
