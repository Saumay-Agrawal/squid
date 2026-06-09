"use client";

import { ChevronDown, Wallet } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import type { KnownAddress } from "@/lib/dashboard";
import { shortenAddress, startCase } from "@/lib/utils";

export function ConnectWallet({
  addresses,
  selectedAddress,
  onSelectAddress,
}: {
  addresses: KnownAddress[];
  selectedAddress: string;
  onSelectAddress: (address: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const active = addresses.find((entry) => entry.address === selectedAddress) ?? addresses[0] ?? null;

  return (
    <div className="relative">
      <Button variant="outline" className="min-w-44 justify-between" onClick={() => setOpen((value) => !value)}>
        <span className="flex items-center gap-2">
          <Wallet className="h-4 w-4" />
          {active ? active.label : "Select Wallet"}
        </span>
        <ChevronDown className="h-4 w-4" />
      </Button>

      {open ? (
        <div className="absolute right-0 z-30 mt-2 w-72 rounded-2xl border border-border bg-popover p-2 shadow-lg">
          {addresses.map((entry) => (
            <button
              key={entry.address}
              type="button"
              className="flex w-full items-center justify-between rounded-xl px-3 py-3 text-left hover:bg-accent"
              onClick={() => {
                onSelectAddress(entry.address);
                setOpen(false);
              }}
            >
              <div>
                <div className="text-sm font-medium">
                  {entry.label}
                  {entry.tier ? <span className="ml-2 text-xs text-muted-foreground">{startCase(entry.tier)}</span> : null}
                </div>
                <div className="font-mono text-xs text-muted-foreground">{shortenAddress(entry.address)}</div>
              </div>
              {entry.address === selectedAddress ? <span className="text-xs text-primary">Selected</span> : null}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
