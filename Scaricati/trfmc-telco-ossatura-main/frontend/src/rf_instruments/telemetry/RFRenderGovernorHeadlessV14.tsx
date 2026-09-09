import { useEffect, useRef } from "react";

type GovernorProfile = "ULTRA" | "HIGH" | "BALANCED" | "SAFE" | "BACKGROUND";

type GovernorPolicy = {
  profile: GovernorProfile;
  fpsTarget: number;
  waterfallEveryNFrames: number;
  iqPointBudget: number;
  animationEnabled: boolean;
  reason: string;
  timestamp: string;
};

const STORAGE_KEY = "TRFMC_RF_RENDER_GOVERNOR_V14_POLICY";
const EVENT_NAME = "trfmc:rf-render-governor:v14";

function buildPolicy(fps: number, jitterMs: number, visibility: DocumentVisibilityState): GovernorPolicy {
  let profile: GovernorProfile = "ULTRA";
  let reason = "headless V14 policy";

  if (visibility === "hidden") {
    profile = "BACKGROUND";
    reason = "document hidden";
  } else if (fps < 24 || jitterMs > 42) {
    profile = "SAFE";
    reason = "severe UI pressure";
  } else if (fps < 42 || jitterMs > 28) {
    profile = "BALANCED";
    reason = "moderate UI pressure";
  } else if (fps < 55 || jitterMs > 18) {
    profile = "HIGH";
    reason = "minor UI pressure";
  }

  const map: Record<GovernorProfile, Omit<GovernorPolicy, "profile" | "reason" | "timestamp">> = {
    ULTRA: {
      fpsTarget: 60,
      waterfallEveryNFrames: 1,
      iqPointBudget: 800,
      animationEnabled: true
    },
    HIGH: {
      fpsTarget: 50,
      waterfallEveryNFrames: 2,
      iqPointBudget: 500,
      animationEnabled: true
    },
    BALANCED: {
      fpsTarget: 36,
      waterfallEveryNFrames: 3,
      iqPointBudget: 320,
      animationEnabled: true
    },
    SAFE: {
      fpsTarget: 24,
      waterfallEveryNFrames: 5,
      iqPointBudget: 160,
      animationEnabled: true
    },
    BACKGROUND: {
      fpsTarget: 5,
      waterfallEveryNFrames: 12,
      iqPointBudget: 64,
      animationEnabled: false
    }
  };

  return {
    profile,
    reason,
    timestamp: new Date().toISOString(),
    ...map[profile]
  };
}

function publish(policy: GovernorPolicy) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(policy));
  window.dispatchEvent(new CustomEvent(EVENT_NAME, { detail: policy }));
}

export function RFRenderGovernorHeadlessV14() {
  const frames = useRef<number[]>([]);
  const raf = useRef<number | null>(null);
  const lastPublish = useRef(0);

  useEffect(() => {
    const loop = (t: number) => {
      const list = frames.current;
      list.push(t);

      while (list.length > 90) list.shift();

      if (list.length > 12) {
        const deltas = list.slice(1).map((value, index) => value - list[index]);
        const avg = deltas.reduce((a, b) => a + b, 0) / deltas.length;
        const max = Math.max(...deltas);
        const min = Math.min(...deltas);

        const fps = Math.round(1000 / avg);
        const jitterMs = Math.round((max - min) * 10) / 10;
        const now = performance.now();

        if (now - lastPublish.current > 1000) {
          publish(buildPolicy(fps, jitterMs, document.visibilityState));
          lastPublish.current = now;
        }
      }

      raf.current = requestAnimationFrame(loop);
    };

    raf.current = requestAnimationFrame(loop);

    return () => {
      if (raf.current !== null) cancelAnimationFrame(raf.current);
    };
  }, []);

  return null;
}
