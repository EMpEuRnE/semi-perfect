"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";
import { useFormStatus } from "react-dom";
import { LoaderCircle } from "lucide-react";
import { Button } from "@/components/ui/button";

type PendingSubmitButtonProps = Omit<ButtonHTMLAttributes<HTMLButtonElement>, "type"> & {
  children: ReactNode;
  pendingLabel: string;
  variant?: "primary" | "secondary" | "ghost";
};

export function PendingSubmitButton({
  children,
  pendingLabel,
  disabled,
  ...props
}: PendingSubmitButtonProps) {
  const { pending } = useFormStatus();

  return (
    <Button type="submit" disabled={pending || disabled} aria-busy={pending} {...props}>
      {pending ? (
        <>
          <LoaderCircle size={16} className="animate-spin" aria-hidden="true" />
          {pendingLabel}
        </>
      ) : children}
    </Button>
  );
}
