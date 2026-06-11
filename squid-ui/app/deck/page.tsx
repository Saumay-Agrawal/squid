import type { Metadata } from "next";

import { DeckPresentation } from "@/components/presentation/deck-presentation";

export const metadata: Metadata = {
  title: "Squid Deck",
  description: "Presentation route for the Squid passive LP observability pitch.",
};

export default function DeckPage() {
  return <DeckPresentation />;
}
