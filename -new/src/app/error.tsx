"use client";
import { Button } from "@/components/ui/button";
export default function ApplicationError({reset}:{reset:()=>void}) {
 return <main className="mx-auto max-w-xl space-y-4 p-6" role="alert"><h1 className="text-2xl font-bold">โหลดหน้านี้ไม่สำเร็จ</h1><p>กรุณาลองใหม่อีกครั้ง หากยังมีปัญหาให้ตรวจการเชื่อมต่อระบบ</p><Button onClick={reset}>ลองใหม่</Button></main>;
}
