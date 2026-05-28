"use client";

import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, ExternalLink, RefreshCw, Send, Wallet } from "lucide-react";
import { isAddress, type Address, type Hash } from "viem";

import {
  anvilRpcUrl,
  getAnvilAccounts,
  publicClient,
  sendTestTransfer,
  shortAddress,
  type AnvilAccount,
} from "@/lib/anvil";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ThemeToggle } from "@/components/theme-toggle";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type TransferReceipt = {
  hash: Hash;
  from: Address;
  to: Address;
  amountEth: string;
};

const DEFAULT_AMOUNT = "0.01";

function formatBalance(balanceEth: string) {
  return `${Number(balanceEth).toFixed(4)} ETH`;
}

function WalletSelector({
  accounts,
  isError,
  isLoading,
  selectedAddress,
  onSelect,
}: {
  accounts: AnvilAccount[];
  isError: boolean;
  isLoading: boolean;
  selectedAddress: Address | "";
  onSelect: (address: Address) => void;
}) {
  const placeholder = isLoading ? "Loading wallets..." : "Select wallet";

  return (
    <Select
      value={selectedAddress}
      onValueChange={(value) => onSelect(value as Address)}
      disabled={isError || isLoading || accounts.length === 0}
    >
      <SelectTrigger className="h-9 w-full min-w-0 max-w-full gap-2 md:w-[230px]">
        <Wallet className="size-4 text-muted-foreground" />
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent align="end" className="w-[280px]">
        <SelectGroup>
          <SelectLabel>Wallets</SelectLabel>
          {accounts.map((account, index) => (
            <SelectItem key={account.address} value={account.address}>
              <span className="flex w-full min-w-0 items-center justify-between gap-3 font-mono">
                <span className="min-w-0 truncate font-mono">
                  #{index} {shortAddress(account.address)}
                </span>
                <span className="shrink-0 text-xs text-muted-foreground">
                  {formatBalance(account.balanceEth)}
                </span>
              </span>
            </SelectItem>
          ))}
        </SelectGroup>
      </SelectContent>
    </Select>
  );
}

export function AccountDashboard() {
  const queryClient = useQueryClient();
  const [selectedAddress, setSelectedAddress] = useState<Address | "">("");
  const [recipientAddress, setRecipientAddress] = useState<Address | "">("");
  const [amountEth, setAmountEth] = useState(DEFAULT_AMOUNT);
  const [lastReceipt, setLastReceipt] = useState<TransferReceipt | null>(null);

  const accountsQuery = useQuery({
    queryKey: ["anvil-accounts"],
    queryFn: getAnvilAccounts,
    refetchInterval: 4_000,
  });

  const accounts = useMemo(
    () => accountsQuery.data ?? [],
    [accountsQuery.data],
  );
  const selectedAccount = accounts.find(
    (account) => account.address === selectedAddress,
  );

  function handleSelectWallet(address: Address) {
    setSelectedAddress(address);
    if (recipientAddress === address) {
      setRecipientAddress("");
    }
  }

  const transferMutation = useMutation({
    mutationFn: async () => {
      if (!selectedAddress || !recipientAddress) {
        throw new Error("Choose a sender from the header and a recipient.");
      }

      if (selectedAddress === recipientAddress) {
        throw new Error("Choose two different accounts.");
      }

      if (!isAddress(selectedAddress) || !isAddress(recipientAddress)) {
        throw new Error("Sender and recipient must be valid addresses.");
      }

      const hash = await sendTestTransfer({
        from: selectedAddress,
        to: recipientAddress,
        amountEth,
      });

      await publicClient.waitForTransactionReceipt({ hash });

      return {
        hash,
        from: selectedAddress,
        to: recipientAddress,
        amountEth,
      };
    },
    onSuccess: async (receipt) => {
      setLastReceipt(receipt);
      await queryClient.invalidateQueries({ queryKey: ["anvil-accounts"] });
    },
  });

  const canSend =
    Boolean(selectedAddress) &&
    Boolean(recipientAddress) &&
    selectedAddress !== recipientAddress &&
    Number(amountEth) > 0 &&
    !transferMutation.isPending;

  return (
    <main className="min-h-screen bg-background">
      <header className="border-b bg-background">
        <nav className="mx-auto grid w-full max-w-7xl gap-3 px-4 py-4 sm:px-6 md:grid-cols-[1fr_auto_1fr] md:items-center lg:px-8">
          <div className="min-w-0">
            <h1 className="text-xl font-semibold tracking-normal">Squid</h1>
          </div>

          <div className="flex min-w-0 items-center gap-2 md:justify-center">
            <Badge variant="outline" className="rounded-md">
              Local Anvil
            </Badge>
            <span className="min-w-0 truncate text-sm text-muted-foreground">
              {anvilRpcUrl}
            </span>
          </div>

          <div className="flex min-w-0 flex-col gap-2 sm:flex-row sm:items-center md:justify-end">
            <WalletSelector
              accounts={accounts}
              isError={accountsQuery.isError}
              isLoading={accountsQuery.isLoading}
              selectedAddress={selectedAddress}
              onSelect={handleSelectWallet}
            />
            <ThemeToggle />
          </div>
        </nav>
      </header>

      <div className="mx-auto flex w-full max-w-3xl flex-col gap-6 px-4 py-8 sm:px-6 lg:px-8">
        {accountsQuery.isError ? (
          <Alert variant="destructive">
            <AlertTitle>Anvil RPC is unreachable</AlertTitle>
            <AlertDescription>
              Start Anvil on {anvilRpcUrl}, then refresh this page.
            </AlertDescription>
          </Alert>
        ) : null}

        {accounts.length === 0 && !accountsQuery.isLoading && !accountsQuery.isError ? (
          <Alert>
            <AlertTitle>No wallets found</AlertTitle>
            <AlertDescription>
              No unlocked Anvil wallets were returned by {anvilRpcUrl}.
            </AlertDescription>
          </Alert>
        ) : null}

        {lastReceipt ? (
          <Alert>
            <CheckCircle2 className="size-4" />
            <AlertTitle>Transaction confirmed</AlertTitle>
            <AlertDescription className="break-all">
              {lastReceipt.amountEth} ETH from {shortAddress(lastReceipt.from)}{" "}
              to {shortAddress(lastReceipt.to)}. Hash: {lastReceipt.hash}
            </AlertDescription>
          </Alert>
        ) : null}

        <Card className="rounded-lg">
          <CardHeader>
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <CardTitle>Test Transfer</CardTitle>
                <CardDescription>
                  Send ETH between unlocked Anvil accounts.
                </CardDescription>
              </div>
              <Button
                variant="outline"
                onClick={() => accountsQuery.refetch()}
                disabled={accountsQuery.isFetching}
              >
                <RefreshCw
                  className={`size-4 ${accountsQuery.isFetching ? "animate-spin" : ""}`}
                />
                Refresh
              </Button>
            </div>
          </CardHeader>
          <CardContent className="space-y-5">
            {selectedAccount ? (
              <div className="rounded-md border bg-muted/40 p-3">
                <p className="text-xs font-medium uppercase text-muted-foreground">
                  Sender
                </p>
                <div className="mt-1 flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
                  <p className="break-all font-mono text-sm">
                    {selectedAccount.address}
                  </p>
                  <p className="shrink-0 font-mono text-sm text-muted-foreground">
                    {formatBalance(selectedAccount.balanceEth)}
                  </p>
                </div>
              </div>
            ) : (
              <Alert>
                <Wallet className="size-4" />
                <AlertTitle>Select a wallet</AlertTitle>
                <AlertDescription>
                  Select a wallet from the header to send test ETH.
                </AlertDescription>
              </Alert>
            )}

            <div className="space-y-2">
              <Label>Recipient</Label>
              <Select
                value={recipientAddress}
                onValueChange={(value) =>
                  setRecipientAddress(value as Address)
                }
                disabled={accounts.length === 0}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Select recipient" />
                </SelectTrigger>
                <SelectContent>
                  {accounts.map((account, index) => (
                    <SelectItem
                      key={account.address}
                      value={account.address}
                      disabled={account.address === selectedAddress}
                    >
                      #{index} {shortAddress(account.address)} -{" "}
                      {formatBalance(account.balanceEth)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="amount">Amount</Label>
              <Input
                id="amount"
                inputMode="decimal"
                value={amountEth}
                onChange={(event) => setAmountEth(event.target.value)}
              />
            </div>

            {transferMutation.isError ? (
              <Alert variant="destructive">
                <AlertTitle>Transfer failed</AlertTitle>
                <AlertDescription>
                  {transferMutation.error.message}
                </AlertDescription>
              </Alert>
            ) : null}

            <Button
              className="w-full"
              disabled={!canSend}
              onClick={() => transferMutation.mutate()}
            >
              {transferMutation.isPending ? (
                <RefreshCw className="size-4 animate-spin" />
              ) : (
                <Send className="size-4" />
              )}
              Send Test Transaction
            </Button>

            {lastReceipt ? (
              <a
                className="flex items-center gap-2 break-all text-xs text-muted-foreground hover:text-foreground"
                href="#"
                onClick={(event) => event.preventDefault()}
              >
                <ExternalLink className="size-3.5 shrink-0" />
                {lastReceipt.hash}
              </a>
            ) : null}
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
