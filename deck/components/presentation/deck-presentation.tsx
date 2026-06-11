"use client";

import {
  Activity,
  ArrowLeft,
  ArrowRight,
  AudioWaveform,
  Blocks,
  BrainCircuit,
  ChartNoAxesCombined,
  CircleGauge,
  Compass,
  DatabaseZap,
  Eye,
  Orbit,
  RadioTower,
  ScanSearch,
  Sparkles,
  Workflow,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import {
  currentDecisionFlow,
  ecosystemUsers,
  infrastructurePillars,
  marketGapRows,
  metricGroups,
  passiveLpQuestions,
  passiveVsActive,
  presentationSlides,
  roadmapPhases,
  solutionPillars,
  squidDecisionFlow,
  validationSignals,
  type PresentationSlide,
  type PresentationSlideId,
} from "@/lib/presentation-content";
import { cn } from "@/lib/utils";

const slideIcons = {
  hero: Sparkles,
  problem: Eye,
  timing: Activity,
  "passive-lps": Compass,
  gap: ScanSearch,
  validation: AudioWaveform,
  solution: DatabaseZap,
  flow: Workflow,
  metrics: ChartNoAxesCombined,
  decision: CircleGauge,
  pillars: Blocks,
  ecosystem: Orbit,
  roadmap: BrainCircuit,
  closing: RadioTower,
} as const;

export function DeckPresentation() {
  const trackRef = useRef<HTMLDivElement | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [isDesktop, setIsDesktop] = useState(false);

  useEffect(() => {
    const media = window.matchMedia("(min-width: 1024px)");
    const update = () => setIsDesktop(media.matches);

    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  useEffect(() => {
    if (!isDesktop) return;

    function handleScroll() {
      const track = trackRef.current;
      if (!track) return;

      const width = track.clientWidth;
      if (width === 0) return;

      const nextIndex = Math.round(track.scrollLeft / width);
      setActiveIndex(Math.max(0, Math.min(presentationSlides.length - 1, nextIndex)));
    }

    const track = trackRef.current;
    if (!track) return;

    handleScroll();
    track.addEventListener("scroll", handleScroll, { passive: true });
    return () => track.removeEventListener("scroll", handleScroll);
  }, [isDesktop]);

  useEffect(() => {
    if (!isDesktop) return;

    function handleKeydown(event: KeyboardEvent) {
      if (!["ArrowLeft", "ArrowRight", "PageUp", "PageDown", "Home", "End"].includes(event.key)) {
        return;
      }

      event.preventDefault();

      if (event.key === "Home") {
        scrollToSlide(0);
        return;
      }

      if (event.key === "End") {
        scrollToSlide(presentationSlides.length - 1);
        return;
      }

      const delta = event.key === "ArrowRight" || event.key === "PageDown" ? 1 : -1;
      scrollToSlide(activeIndex + delta);
    }

    window.addEventListener("keydown", handleKeydown);
    return () => window.removeEventListener("keydown", handleKeydown);
  }, [activeIndex, isDesktop]);

  const progress = useMemo(
    () => ((activeIndex + 1) / presentationSlides.length) * 100,
    [activeIndex],
  );

  function scrollToSlide(index: number) {
    const track = trackRef.current;
    if (!track) return;

    const nextIndex = Math.max(0, Math.min(presentationSlides.length - 1, index));
    track.scrollTo({
      left: nextIndex * track.clientWidth,
      behavior: "smooth",
    });
  }

  return (
    <div className="min-h-screen overflow-hidden text-white">
      <DeckBackdrop />

      <header className="pointer-events-none fixed inset-x-0 top-0 z-40">
        <div className="mx-auto flex max-w-[1600px] items-center justify-between gap-6 px-4 py-4 sm:px-6 lg:px-10">
          <div className="pointer-events-auto rounded-full border border-white/12 bg-slate-950/55 px-4 py-2 backdrop-blur-xl">
            <p className="text-[0.65rem] uppercase tracking-[0.38em] text-cyan-200/75">Squid</p>
            <p className="text-sm font-medium text-white/90">Passive LP observability deck</p>
          </div>

          <div className="pointer-events-auto hidden items-center gap-4 lg:flex">
            <button
              type="button"
              onClick={() => scrollToSlide(activeIndex - 1)}
              className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-white/12 bg-slate-950/55 text-white/80 backdrop-blur-xl transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-35"
              disabled={activeIndex === 0}
              aria-label="Previous slide"
            >
              <ArrowLeft className="h-4 w-4" />
            </button>
            <div className="w-64">
              <div className="mb-2 flex items-center justify-between text-[0.7rem] uppercase tracking-[0.24em] text-white/55">
                <span>{presentationSlides[activeIndex]?.kicker}</span>
                <span>
                  {String(activeIndex + 1).padStart(2, "0")} / {String(presentationSlides.length).padStart(2, "0")}
                </span>
              </div>
              <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-cyan-300 via-sky-400 to-emerald-300 transition-[width] duration-500"
                  style={{ width: `${progress}%` }}
                />
              </div>
            </div>
            <button
              type="button"
              onClick={() => scrollToSlide(activeIndex + 1)}
              className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-white/12 bg-slate-950/55 text-white/80 backdrop-blur-xl transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-35"
              disabled={activeIndex === presentationSlides.length - 1}
              aria-label="Next slide"
            >
              <ArrowRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </header>

      {isDesktop ? (
        <main
          ref={trackRef}
          className="deck-track relative z-10 hidden h-screen snap-x snap-mandatory overflow-x-auto overflow-y-hidden lg:flex"
        >
          {presentationSlides.map((slide, index) => (
            <section
              key={slide.id}
              className="deck-slide flex min-h-screen min-w-full snap-center items-center justify-center px-4 py-24 sm:px-6 lg:px-10"
              aria-current={index === activeIndex ? "true" : undefined}
            >
              <SlideSurface slide={slide} index={index} active={index === activeIndex} />
            </section>
          ))}
        </main>
      ) : (
        <main className="relative z-10 mx-auto flex max-w-[1600px] flex-col gap-6 px-4 pb-16 pt-24 sm:px-6">
          <div className="rounded-[1.6rem] border border-white/10 bg-slate-950/50 px-4 py-3 text-sm text-white/72 backdrop-blur-xl">
            Desktop uses the horizontal presentation flow. Mobile falls back to a vertical narrative.
          </div>
          {presentationSlides.map((slide, index) => (
            <section key={slide.id} className="min-h-[70vh]">
              <SlideSurface slide={slide} index={index} active />
            </section>
          ))}
        </main>
      )}
    </div>
  );
}

function SlideSurface({
  slide,
  index,
  active,
}: {
  slide: PresentationSlide;
  index: number;
  active: boolean;
}) {
  const Icon = slideIcons[slide.id];

  return (
    <div
      className={cn(
        "deck-stage grid w-full max-w-[1500px] gap-8 rounded-[2.5rem] border border-white/10 bg-[linear-gradient(180deg,rgba(8,15,24,0.88),rgba(7,18,28,0.72))] p-6 shadow-[0_40px_160px_rgba(0,0,0,0.42)] backdrop-blur-xl transition duration-500 md:p-8 xl:grid-cols-[0.92fr_1.08fr] xl:p-12",
        active ? "opacity-100" : "opacity-80",
      )}
    >
      <div className="flex min-w-0 flex-col justify-between gap-8">
        <div className="flex min-h-full flex-1 flex-col justify-between gap-10">
          <div className="space-y-6">
            <div className="inline-flex items-center gap-3 rounded-full border border-cyan-200/14 bg-cyan-300/10 px-4 py-2 text-cyan-100/85">
              <Icon className="h-4 w-4" />
              <span className="text-[0.72rem] uppercase tracking-[0.32em]">{slide.kicker}</span>
            </div>

            <div className="max-w-3xl space-y-4">
              <p className="text-sm uppercase tracking-[0.34em] text-white/38">
                Slide {String(index + 1).padStart(2, "0")}
              </p>
              <h1 className="text-4xl font-semibold tracking-[-0.05em] text-white sm:text-5xl xl:text-6xl">
                {slide.title}
              </h1>
            </div>
          </div>

          <div className="max-w-2xl">
            <p className="max-w-2xl text-base leading-8 text-slate-300 xl:text-lg">{slide.summary}</p>
          </div>
        </div>
      </div>

      <div className="min-w-0">{renderSlideCanvas(slide.id)}</div>
    </div>
  );
}

function renderSlideCanvas(id: PresentationSlideId) {
  switch (id) {
    case "hero":
      return <HeroCanvas />;
    case "problem":
      return <QuestionCanvas />;
    case "timing":
      return <TimingCanvas />;
    case "passive-lps":
      return <ComparisonCanvas />;
    case "gap":
      return <GapCanvas />;
    case "validation":
      return <ValidationCanvas />;
    case "solution":
      return <SolutionCanvas />;
    case "flow":
      return <FlowCanvas />;
    case "metrics":
      return <MetricsCanvas />;
    case "decision":
      return <DecisionCanvas />;
    case "pillars":
      return <PillarsCanvas />;
    case "ecosystem":
      return <EcosystemCanvas />;
    case "roadmap":
      return <RoadmapCanvas />;
    case "closing":
      return <ClosingCanvas />;
    default:
      return null;
  }
}

function DeckBackdrop() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_8%_12%,rgba(56,189,248,0.16),transparent_20%),radial-gradient(circle_at_78%_24%,rgba(45,212,191,0.15),transparent_18%),radial-gradient(circle_at_55%_85%,rgba(59,130,246,0.14),transparent_24%),linear-gradient(180deg,#06101a_0%,#07131d_45%,#08111a_100%)]" />
      <div className="deck-grid absolute inset-0 opacity-25" />
      <div className="deck-float absolute left-[6%] top-[12%] h-72 w-72 rounded-full bg-cyan-300/12 blur-3xl" />
      <div className="deck-float-delayed absolute right-[8%] top-[24%] h-80 w-80 rounded-full bg-sky-400/10 blur-3xl" />
      <div className="deck-float absolute bottom-[10%] left-[42%] h-96 w-96 rounded-full bg-emerald-300/8 blur-3xl" />
    </div>
  );
}

function Canvas({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div
      className={cn(
        "relative flex h-full flex-col overflow-hidden rounded-[2rem] border border-white/10 bg-[linear-gradient(180deg,rgba(255,255,255,0.06),rgba(255,255,255,0.025))] p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)] sm:p-6",
        className,
      )}
    >
      {children}
    </div>
  );
}

function HeroCanvas() {
  return (
    <Canvas className="deck-pulse min-h-[520px]">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_22%,rgba(103,232,249,0.2),transparent_18rem),radial-gradient(circle_at_75%_30%,rgba(59,130,246,0.16),transparent_14rem)]" />
      <div className="relative flex h-full flex-col justify-center">
        <div className="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
          <div className="flex h-full flex-col justify-center space-y-4 rounded-[1.75rem] border border-white/10 bg-black/16 p-5">
            <p className="text-xs uppercase tracking-[0.28em] text-white/45">Passive LP state</p>
            <div className="space-y-4">
              <SignalBar label="Visibility" value="Low" width="26%" tone="bg-slate-300" />
              <SignalBar label="Signal quality" value="Fragmented" width="32%" tone="bg-slate-400" />
              <SignalBar label="Decision confidence" value="Guesswork" width="24%" tone="bg-slate-500" />
            </div>
          </div>
          <div className="flex h-full flex-col justify-center space-y-4 rounded-[1.75rem] border border-cyan-200/14 bg-cyan-300/10 p-5">
            <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/75">With Squid</p>
            <div className="space-y-4">
              <SignalBar label="Visibility" value="High" width="92%" tone="bg-cyan-300" />
              <SignalBar label="Signal quality" value="Structured" width="84%" tone="bg-sky-400" />
              <SignalBar label="Decision confidence" value="Actionable" width="78%" tone="bg-emerald-300" />
            </div>
          </div>
        </div>
        <div className="relative mt-5 rounded-[1.75rem] border border-white/10 bg-white/[0.04] p-5">
          <div className="flex items-center justify-between">
            <span className="text-sm text-white/70">Blind yield bet</span>
            <span className="text-sm text-cyan-100">Instrumented strategy</span>
          </div>
          <div className="mt-5 h-3 rounded-full bg-white/10">
            <div className="h-full w-[88%] rounded-full bg-gradient-to-r from-cyan-300 via-sky-400 to-emerald-300" />
          </div>
        </div>
      </div>
    </Canvas>
  );
}

function SignalBar({
  label,
  value,
  width,
  tone,
}: {
  label: string;
  value: string;
  width: string;
  tone: string;
}) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between text-sm">
        <span className="text-white/65">{label}</span>
        <span className="text-white">{value}</span>
      </div>
      <div className="h-2.5 rounded-full bg-white/8">
        <div className={cn("h-full rounded-full transition-[width] duration-700", tone)} style={{ width }} />
      </div>
    </div>
  );
}

function QuestionCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-3">
        {passiveLpQuestions.map(([question, answer]) => (
          <div
            key={question}
            className="grid h-full gap-3 rounded-[1.4rem] border border-white/10 bg-white/[0.04] p-4 lg:grid-cols-[1fr_auto] lg:items-center"
          >
            <div className="text-base text-white">{question}</div>
            <div className="rounded-full border border-amber-300/20 bg-amber-300/10 px-4 py-2 text-sm text-amber-100">
              {answer}
            </div>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function TimingCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="flex h-full flex-col">
        <div className="grid auto-rows-fr gap-4 md:grid-cols-2">
          <BigDecisionCard title="Decision 01" body="When to enter" />
          <BigDecisionCard title="Decision 02" body="When to exit" />
        </div>
        <div className="mt-auto pt-4">
          <div className="rounded-[1.8rem] border border-white/10 bg-white/[0.04] p-5">
            <p className="text-xs uppercase tracking-[0.28em] text-white/45">Observation</p>
            <p className="mt-3 text-xl font-medium text-white">
              Timing dominates LP performance, but the timing inputs are still under-instrumented.
            </p>
          </div>
        </div>
      </div>
    </Canvas>
  );
}

function BigDecisionCard({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex h-full flex-col rounded-[1.8rem] border border-white/10 bg-black/15 p-6">
      <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/70">{title}</p>
      <p className="mt-12 text-3xl font-semibold tracking-[-0.04em] text-white">{body}</p>
    </div>
  );
}

function ComparisonCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4">
        <div className="grid grid-cols-2 gap-4">
          <HeaderChip label="Active LPs" />
          <HeaderChip label="Passive LPs" active />
        </div>
        {passiveVsActive.map(([active, passive]) => (
          <div key={active} className="grid grid-cols-2 gap-4">
            <Cell>{active}</Cell>
            <Cell active>{passive}</Cell>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function HeaderChip({ label, active = false }: { label: string; active?: boolean }) {
  return (
    <div
      className={cn(
        "flex h-full items-center justify-center px-2 py-2 text-center text-sm font-semibold uppercase tracking-[0.32em]",
        active
          ? "text-cyan-100"
          : "text-white/72",
      )}
    >
      {label}
    </div>
  );
}

function Cell({ children, active = false }: { children: React.ReactNode; active?: boolean }) {
  return (
    <div
      className={cn(
        "flex h-full items-center justify-center rounded-[1.4rem] border px-4 py-4 text-center text-sm",
        active
          ? "border-cyan-200/16 bg-cyan-300/10 text-cyan-50"
          : "border-white/10 bg-white/[0.04] text-white/82",
      )}
    >
      {children}
    </div>
  );
}

function GapCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-3">
        {marketGapRows.map(([tool, limitation], index) => (
          <div key={tool} className="flex h-full flex-col rounded-[1.5rem] border border-white/10 bg-white/[0.04] p-4">
            <div className="flex flex-wrap items-center gap-3">
              <span className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-cyan-200/14 bg-cyan-300/10 text-cyan-100">
                {index + 1}
              </span>
              <span className="text-base font-medium text-white">{tool}</span>
            </div>
            <p className="mt-3 text-sm leading-7 text-slate-300">{limitation}</p>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function ValidationCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4">
        {validationSignals.map((entry) => (
          <div
            key={entry.source}
            className="flex h-full flex-col justify-center rounded-[1.6rem] border border-white/10 bg-white/[0.04] p-5"
          >
            <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/70">{entry.source}</p>
            <p className="mt-3 text-sm leading-7 text-white/90">{entry.signal}</p>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function SolutionCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4">
        {solutionPillars.map((pillar, index) => (
          <div
            key={pillar.title}
            className="grid h-full items-center gap-4 rounded-[1.7rem] border border-white/10 bg-white/[0.04] p-5 lg:grid-cols-[auto_1fr]"
          >
            <div className="inline-flex h-14 w-14 items-center justify-center rounded-[1.2rem] border border-cyan-200/14 bg-cyan-300/10 text-xl font-semibold text-cyan-100">
              0{index + 1}
            </div>
            <div>
              <p className="text-lg font-medium text-white">{pillar.title}</p>
              <p className="mt-2 text-sm leading-7 text-slate-300">{pillar.body}</p>
            </div>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function FlowCanvas() {
  const rows = [
    ["Uniswap v4 Pool", "Squid Hook", "Pool + Position Metrics", "Dashboard / Simulator", "Passive LP Decisions"],
    ["Pools across chains", "Reactive Network watches", "Squid triggers alerts / actions", "Unified liquidity management"],
  ];

  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4">
        {rows.map((items, index) => (
          <div
            key={items[0]}
            className="flex h-full flex-col justify-center rounded-[1.7rem] border border-white/10 bg-white/[0.04] p-4"
          >
            <p className="mb-4 text-xs uppercase tracking-[0.28em] text-white/45">
              {index === 0 ? "Core flow" : "Cross-chain vision"}
            </p>
            <div className="flex flex-col justify-center gap-3 xl:flex-row xl:items-stretch">
              {items.map((item, itemIndex) => (
                <div key={item} className="flex items-center gap-3 xl:min-w-0 xl:flex-1">
                  <div className="flex w-full items-center justify-center rounded-[1.2rem] border border-cyan-200/12 bg-cyan-300/8 px-3 py-4 text-center text-sm text-white/90">
                    {item}
                  </div>
                  {itemIndex < items.length - 1 ? (
                    <ArrowRight className="hidden h-4 w-4 text-cyan-200/80 xl:block" />
                  ) : null}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function MetricsCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="flex h-full flex-col justify-center gap-4">
        <div className="grid auto-rows-fr gap-4 md:grid-cols-2">
          {metricGroups.map((metric) => (
            <div key={metric.title} className="deck-card flex h-full flex-col rounded-[1.7rem] border border-white/10 bg-white/[0.04] p-5">
              <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/70">{metric.title}</p>
              <div className="mt-4 grid gap-3">
                {metric.metrics.map((item) => (
                  <div
                    key={item}
                    className="rounded-[1.1rem] border border-cyan-200/10 bg-cyan-300/8 px-4 py-3 text-sm leading-6 text-cyan-50"
                  >
                    {item}
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
        <div className="deck-card rounded-[1.7rem] border border-white/10 bg-white/[0.04] p-5">
          <p className="text-sm leading-7 text-slate-300">
            More relevant metrics will be added in future as Squid expands the observability layer and sharpens LP-facing
            signals.
          </p>
        </div>
      </div>
    </Canvas>
  );
}

function DecisionCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4 lg:grid-cols-2">
        <FlowColumn title="Current LP experience" items={currentDecisionFlow} />
        <FlowColumn title="Squid experience" items={squidDecisionFlow} accent />
      </div>
    </Canvas>
  );
}

function FlowColumn({
  title,
  items,
  accent = false,
}: {
  title: string;
  items: string[];
  accent?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex h-full flex-col rounded-[1.7rem] border p-5",
        accent ? "border-cyan-200/16 bg-cyan-300/10" : "border-white/10 bg-white/[0.04]",
      )}
    >
      <p className="text-xs uppercase tracking-[0.28em] text-white/45">{title}</p>
      <div className="mt-4 grid gap-3">
        {items.map((item, index) => (
          <div key={item} className="flex items-center gap-3 rounded-[1.15rem] border border-white/8 bg-black/12 px-4 py-3">
            <span
              className={cn(
                "inline-flex h-8 w-8 items-center justify-center rounded-full text-xs",
                accent ? "bg-cyan-200/20 text-cyan-50" : "bg-white/8 text-white/70",
              )}
            >
              {index + 1}
            </span>
            <span className="text-sm text-white/90">{item}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function PillarsCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4">
        {infrastructurePillars.map((pillar) => (
          <div
            key={pillar.title}
            className="flex h-full flex-col justify-center rounded-[1.7rem] border border-white/10 bg-white/[0.04] p-5"
          >
            <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/70">{pillar.title}</p>
            <p className="mt-4 text-sm leading-7 text-slate-300">{pillar.body}</p>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function EcosystemCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-3">
        {ecosystemUsers.map(([user, outcome]) => (
          <div
            key={user}
            className="grid h-full items-center gap-3 rounded-[1.5rem] border border-white/10 bg-white/[0.04] p-4 lg:grid-cols-[220px_1fr]"
          >
            <div className="text-lg font-medium text-white">{user}</div>
            <div className="text-sm leading-7 text-slate-300">{outcome}</div>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function RoadmapCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="grid h-full auto-rows-fr gap-4">
        {roadmapPhases.map((phase, index) => (
          <div key={phase.phase} className="flex h-full flex-col rounded-[1.7rem] border border-white/10 bg-white/[0.04] p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/70">{phase.phase}</p>
                <p className="mt-2 text-xl font-semibold text-white">{phase.title}</p>
              </div>
              <div className="rounded-full border border-white/10 bg-black/14 px-4 py-2 text-sm text-white/75">
                Step {index + 1}
              </div>
            </div>
            <p className="mt-3 text-sm leading-7 text-slate-300">{phase.body}</p>
          </div>
        ))}
      </div>
    </Canvas>
  );
}

function ClosingCanvas() {
  return (
    <Canvas className="min-h-[520px]">
      <div className="flex h-full flex-col justify-center gap-4">
        <div className="grid auto-rows-fr gap-4">
          <div className="flex h-full flex-col rounded-[1.8rem] border border-white/10 bg-white/[0.04] p-6">
            <p className="text-xs uppercase tracking-[0.28em] text-white/45">Website</p>
            <p className="mt-4 text-4xl font-semibold tracking-[-0.05em] text-white">saumay.xyz</p>
          </div>
          <div className="flex h-full flex-col rounded-[1.8rem] border border-cyan-200/16 bg-cyan-300/10 p-6">
            <p className="text-xs uppercase tracking-[0.28em] text-cyan-100/70">X</p>
            <p className="mt-4 text-4xl font-semibold tracking-[-0.05em] text-white">@saumay_agrawal</p>
          </div>
        </div>
      </div>
    </Canvas>
  );
}
