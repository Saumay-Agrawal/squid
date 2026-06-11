"use client";

import { ChevronDown, Wallet } from "lucide-react";
import { useState } from "react";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import { isAddressEqual } from "viem";

import { Button } from "@/components/ui/button";
import { HexValue } from "@/components/ui/hex-value";
import type { KnownAddress } from "@/lib/dashboard";
import { cn, startCase } from "@/lib/utils";

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
  const { address: connectedAddress, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const injectedConnector = connectors[0];
  const selectionMatchesSigner =
    active && connectedAddress ? isAddressEqual(active.address as `0x${string}`, connectedAddress) : false;

  return (
    <div className="relative flex items-center gap-2">
      <Button
        variant={isConnected ? "secondary" : "outline"}
        className="min-w-36 justify-between"
        onClick={() => {
          if (isConnected) {
            disconnect();
            return;
          }

          if (injectedConnector) {
            connect({ connector: injectedConnector });
          }
        }}
      >
        <span className="flex items-center gap-2">
          <Wallet className="h-4 w-4" />
          {isConnected ? "Wallet connected" : isPending ? "Connecting..." : "Connect wallet"}
        </span>
      </Button>

      <Button variant="outline" className="min-w-44 justify-between" onClick={() => setOpen((value) => !value)}>
        <span className="flex items-center gap-2">
          <Wallet className="h-4 w-4" />
          {active ? active.label : "Select Account"}
        </span>
        <ChevronDown className="h-4 w-4" />
      </Button>

      {open ? (
        <div className="absolute right-0 top-full z-30 mt-2 w-80 rounded-2xl border border-border bg-popover p-2 shadow-lg">
          {connectedAddress ? (
            <div
              className={cn(
                "mb-2 rounded-xl border px-3 py-3 text-xs",
                selectionMatchesSigner
                  ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
                  : "border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-300",
              )}
            >
              <div className="font-medium">{selectionMatchesSigner ? "Signer matches selected LP" : "Signer mismatch"}</div>
              <HexValue value={connectedAddress} textClassName="text-[11px]" />
            </div>
          ) : null}

          <div className="max-h-96 overflow-y-auto">
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
                    <span className="ml-2 text-xs text-muted-foreground">
                      {startCase(entry.role)}
                      {entry.tier ? ` · ${startCase(entry.tier)}` : ""}
                    </span>
                  </div>
                  <HexValue value={entry.address} textClassName="text-xs text-muted-foreground" />
                </div>
                <div className="text-right text-xs">
                  {entry.address === selectedAddress ? <div className="text-primary">Selected</div> : null}
                  {connectedAddress &&
                  isAddressEqual(entry.address as `0x${string}`, connectedAddress) ? (
                    <div className="text-emerald-600 dark:text-emerald-400">Signer</div>
                  ) : null}
                </div>
              </button>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}
