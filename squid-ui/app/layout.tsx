import type { Metadata } from "next";

import { Providers } from "@/components/providers";

import "./globals.css";

export const metadata: Metadata = {
  title: "Squid UI",
  description: "Seeded Squid market dashboard for local pool, LP, and position snapshots.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-screen">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
