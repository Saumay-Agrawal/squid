"use client";

import { Loader2, PlugZap, Wallet } from "lucide-react";
import { useAccount, useChains, useConnect, useDisconnect, useSwitchChain } from "wagmi";

import { Button } from "@/components/ui/button";
import { shortenAddress } from "@/lib/utils";

const ANVIL_CHAIN_ID = 31337;

export function ConnectWallet() {
  const { address, chain, isConnected } = useAccount();
  const chains = useChains();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  const injectedConnector = connectors.find((connector) => connector.type === "injected") ?? connectors[0];
  const anvilChain = chains.find((candidate) => candidate.id === ANVIL_CHAIN_ID);
  const wrongNetwork = isConnected && chain?.id !== ANVIL_CHAIN_ID;

  if (!isConnected) {
    return (
      <Button
        onClick={() => injectedConnector && connect({ connector: injectedConnector })}
        disabled={!injectedConnector || isPending}
        className="min-w-36"
      >
        {isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <PlugZap className="mr-2 h-4 w-4" />}
        Connect Wallet
      </Button>
    );
  }

  if (wrongNetwork && anvilChain) {
    return (
      <Button onClick={() => switchChain({ chainId: anvilChain.id })} disabled={isSwitching} variant="secondary">
        {isSwitching ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Wallet className="mr-2 h-4 w-4" />}
        Switch to Anvil
      </Button>
    );
  }

  return (
    <Button variant="outline" onClick={() => disconnect()} className="min-w-36">
      <Wallet className="mr-2 h-4 w-4" />
      {shortenAddress(address)}
    </Button>
  );
}

