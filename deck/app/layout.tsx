import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "Squid Deck",
  description: "Founder-style web presentation for Squid's passive LP observability pitch.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
