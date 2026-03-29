import { useState, useEffect, useRef } from "react";

type Tab = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10;
type ImprovementState = { label: string };

const IDLE_WAVEFORM_BARS = Array(22).fill(3);
const IDLE_RECORDING_BARS = Array(26).fill(4);
const IDLE_HUD_BARS = Array(14).fill(4);

function StateButtons({
  states,
  activeIndex,
  onSelect,
}: {
  states: ImprovementState[];
  activeIndex: number;
  onSelect: (index: number) => void;
}) {
  return (
    <div style={{ display: "flex", gap: 5 }}>
      {states.map((state, index) => (
        <button
          key={state.label}
          onClick={() => onSelect(index)}
          style={{
            padding: "3px 8px",
            fontSize: 8,
            borderRadius: 4,
            border: "1px solid rgba(255,255,255,0.1)",
            background:
              index === activeIndex ? "rgba(255,255,255,0.08)" : "transparent",
            color: "rgba(255,255,255,0.45)",
            cursor: "pointer",
            fontFamily: "monospace",
          }}
        >
          {state.label.slice(0, 4)}
        </button>
      ))}
    </div>
  );
}

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>(1);

  const improvements = [
    { id: 1, title: "Waveform Visualizer", tag: "Visual Feedback" },
    { id: 2, title: "Status Pill", tag: "State Clarity" },
    { id: 3, title: "History Cards", tag: "Readability" },
    { id: 4, title: "Recording Mode", tag: "Immersion" },
    { id: 5, title: "Empty State", tag: "Guidance" },
    { id: 6, title: "Settings Layout", tag: "Organization" },
    { id: 7, title: "Floating HUD", tag: "Always-On UI" },
    { id: 8, title: "Onboarding Flow", tag: "First-Run UX" },
    { id: 9, title: "Quick Action Bar", tag: "Efficiency" },
    { id: 10, title: "Color System", tag: "Consistency" },
  ];

  return (
    <div style={{
      minHeight: "100vh",
      background: "#0a0a0f",
      color: "#e8e8f0",
      fontFamily: "'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif",
      display: "flex",
      flexDirection: "column",
    }}>
      <style>{`
        @keyframes pulse { 0%,100% { opacity:1; transform:scale(1); } 50% { opacity:0.5; transform:scale(0.85); } }
        @keyframes shimmer { 0% { transform:translateX(-100%); } 100% { transform:translateX(400%); } }
        * { box-sizing: border-box; }
      `}</style>

      {/* Header */}
      <div style={{
        borderBottom: "1px solid rgba(255,255,255,0.08)",
        padding: "20px 32px",
        display: "flex",
        alignItems: "center",
        gap: "16px",
        background: "rgba(255,255,255,0.02)",
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 10,
          background: "linear-gradient(135deg, #00d4ff 0%, #0099cc 100%)",
          display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18,
        }}>🎙</div>
        <div>
          <div style={{ fontWeight: 700, fontSize: 17, letterSpacing: "-0.3px" }}>
            DexDictate — UX Improvement Proposals
          </div>
          <div style={{ fontSize: 12, color: "rgba(255,255,255,0.4)", marginTop: 2 }}>
            10 before/after mockups · macOS menu-bar dictation app
          </div>
        </div>
      </div>

      <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>
        {/* Sidebar */}
        <div style={{
          width: 220,
          borderRight: "1px solid rgba(255,255,255,0.06)",
          padding: "16px 8px",
          flexShrink: 0,
          overflowY: "auto",
        }}>
          {improvements.map((imp) => (
            <button key={imp.id} onClick={() => setActiveTab(imp.id as Tab)} style={{
              width: "100%", padding: "10px 12px", borderRadius: 8, border: "none",
              background: activeTab === imp.id ? "rgba(0,212,255,0.1)" : "transparent",
              cursor: "pointer", display: "flex", alignItems: "center", gap: 10,
              textAlign: "left", marginBottom: 2, transition: "background 0.15s",
            }}>
              <span style={{
                width: 22, height: 22, borderRadius: 6,
                background: activeTab === imp.id ? "rgba(0,212,255,0.22)" : "rgba(255,255,255,0.06)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 10, fontWeight: 700,
                color: activeTab === imp.id ? "#00d4ff" : "rgba(255,255,255,0.35)",
                flexShrink: 0, fontFamily: "monospace",
              }}>{imp.id}</span>
              <div>
                <div style={{
                  fontSize: 12.5,
                  fontWeight: activeTab === imp.id ? 600 : 400,
                  color: activeTab === imp.id ? "#fff" : "rgba(255,255,255,0.6)",
                  lineHeight: 1.2,
                }}>{imp.title}</div>
                <div style={{
                  fontSize: 10,
                  color: activeTab === imp.id ? "rgba(0,212,255,0.7)" : "rgba(255,255,255,0.25)",
                  marginTop: 2,
                }}>{imp.tag}</div>
              </div>
            </button>
          ))}
        </div>

        {/* Main content */}
        <div style={{ flex: 1, padding: "32px 40px", overflowY: "auto" }}>
          {activeTab === 1 && <Improvement1 />}
          {activeTab === 2 && <Improvement2 />}
          {activeTab === 3 && <Improvement3 />}
          {activeTab === 4 && <Improvement4 />}
          {activeTab === 5 && <Improvement5 />}
          {activeTab === 6 && <Improvement6 />}
          {activeTab === 7 && <Improvement7 />}
          {activeTab === 8 && <Improvement8 />}
          {activeTab === 9 && <Improvement9 />}
          {activeTab === 10 && <Improvement10 />}
        </div>
      </div>
    </div>
  );
}

// ─── Shared Layout ────────────────────────────────────────────────────────────
function ImprovementLayout({ number, title, tag, problem, solution, before, after }: {
  number: number; title: string; tag: string;
  problem: string; solution: string;
  before: React.ReactNode; after: React.ReactNode;
}) {
  return (
    <div>
      <div style={{ marginBottom: 28 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 8 }}>
          <span style={{
            fontSize: 11, fontWeight: 700, fontFamily: "monospace",
            color: "#00d4ff", background: "rgba(0,212,255,0.1)",
            border: "1px solid rgba(0,212,255,0.2)", borderRadius: 5, padding: "2px 8px",
          }}>#{number}</span>
          <span style={{
            fontSize: 10, fontWeight: 600, color: "rgba(255,255,255,0.35)",
            textTransform: "uppercase" as const, letterSpacing: "0.08em",
          }}>{tag}</span>
        </div>
        <h1 style={{ fontSize: 26, fontWeight: 700, margin: 0, letterSpacing: "-0.5px" }}>{title}</h1>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 32 }}>
        <div style={{
          background: "rgba(255,80,80,0.06)", border: "1px solid rgba(255,80,80,0.15)",
          borderRadius: 10, padding: "14px 16px",
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: "#ff5050", letterSpacing: "0.08em", textTransform: "uppercase" as const, marginBottom: 6 }}>⚠ Current Problem</div>
          <p style={{ margin: 0, fontSize: 13, color: "rgba(255,255,255,0.62)", lineHeight: 1.6 }}>{problem}</p>
        </div>
        <div style={{
          background: "rgba(0,212,100,0.06)", border: "1px solid rgba(0,212,100,0.15)",
          borderRadius: 10, padding: "14px 16px",
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: "#00d464", letterSpacing: "0.08em", textTransform: "uppercase" as const, marginBottom: 6 }}>✓ Proposed Solution</div>
          <p style={{ margin: 0, fontSize: 13, color: "rgba(255,255,255,0.62)", lineHeight: 1.6 }}>{solution}</p>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 24 }}>
        {[
          { label: "Before", dot: "#ff5050", border: "rgba(255,255,255,0.07)", labelColor: "rgba(255,255,255,0.3)", content: before },
          { label: "After", dot: "#00d4ff", border: "rgba(0,212,255,0.15)", labelColor: "rgba(0,212,255,0.7)", content: after },
        ].map(({ label, dot, border, labelColor, content }) => (
          <div key={label}>
            <div style={{
              fontSize: 11, fontWeight: 600, color: labelColor,
              textTransform: "uppercase" as const, letterSpacing: "0.1em",
              marginBottom: 12, display: "flex", alignItems: "center", gap: 8,
            }}>
              <span style={{ width: 6, height: 6, borderRadius: "50%", background: dot, display: "inline-block" }} />
              {label}
            </div>
            <div style={{
              background: "rgba(255,255,255,0.025)",
              border: `1px solid ${border}`,
              borderRadius: 14, padding: 24,
              display: "flex", alignItems: "center", justifyContent: "center",
              minHeight: 200,
            }}>
              {content}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Popover Shell ────────────────────────────────────────────────────────────
function MacPopover({ children, width = 280 }: { children: React.ReactNode; width?: number }) {
  return (
    <div style={{
      width, background: "rgba(18,18,28,0.97)", backdropFilter: "blur(20px)",
      borderRadius: 12, border: "1px solid rgba(255,255,255,0.1)",
      overflow: "hidden",
      boxShadow: "0 20px 60px rgba(0,0,0,0.7), 0 0 0 0.5px rgba(255,255,255,0.04)",
      fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
    }}>
      {children}
    </div>
  );
}

// ─── #1 Waveform Visualizer ───────────────────────────────────────────────────
function Improvement1() {
  const [bars, setBars] = useState(() => IDLE_WAVEFORM_BARS);
  const [on, setOn] = useState(true);
  const animRef = useRef<number>(0);

  useEffect(() => {
    if (!on) {
      return;
    }
    const frame = () => {
      setBars(prev => prev.map((_, i) =>
        Math.max(3, Math.round((Math.sin(Date.now() / 200 + i * 0.7) * 0.5 + 0.5 + Math.random() * 0.35) * 30))
      ));
      animRef.current = requestAnimationFrame(frame);
    };
    animRef.current = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(animRef.current);
  }, [on]);

  const displayedBars = on ? bars : IDLE_WAVEFORM_BARS;

  return (
    <ImprovementLayout
      number={1} title="Waveform Visualizer" tag="Visual Feedback"
      problem="A single 6px-tall progress bar labeled 'Input Level' shows audio activity. It's easy to miss, looks utilitarian, and gives no sense of voice energy — you can't tell a whisper from a shout."
      solution="20 animated bars driven by amplitude + sine wave offset. Each bar height responds to audio in real time, giving instant visual confirmation that the mic is picking up your voice. Far more legible at a glance."
      before={
        <MacPopover>
          <div style={{ padding: 16 }}>
            <div style={{ fontSize: 10, color: "rgba(255,255,255,0.35)", marginBottom: 6 }}>Input Level</div>
            <div style={{ height: 6, background: "rgba(255,255,255,0.07)", borderRadius: 3, overflow: "hidden" }}>
              <div style={{ height: "100%", width: "62%", background: "rgba(0,255,0,0.7)", borderRadius: 3 }} />
            </div>
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ padding: "14px 16px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 7, marginBottom: 8 }}>
              <div style={{
                width: 7, height: 7, borderRadius: "50%", background: "#ef4444",
                boxShadow: "0 0 8px #ef4444",
                animation: on ? "pulse 1s ease-in-out infinite" : "none",
              }} />
              <span style={{ fontSize: 10, fontWeight: 700, color: "rgba(255,255,255,0.5)", fontFamily: "monospace", letterSpacing: "0.1em" }}>LISTENING</span>
              <span style={{ marginLeft: "auto", fontSize: 10, color: "rgba(255,80,80,0.6)", fontFamily: "monospace" }}>0:07</span>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 2.5, height: 36 }}>
              {displayedBars.map((h, i) => (
                <div key={i} style={{
                  flex: 1, height: h, borderRadius: 2,
                  background: `linear-gradient(to top, rgba(239,68,68,0.9), rgba(252,165,165,0.4))`,
                  transition: "height 0.05s ease",
                }} />
              ))}
            </div>
            <button onClick={() => setOn(!on)} style={{
              marginTop: 8, width: "100%", background: "transparent", border: "none",
              fontSize: 9, color: "rgba(255,255,255,0.25)", cursor: "pointer", padding: 0,
            }}>{on ? "⏸ pause demo" : "▶ resume demo"}</button>
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #2 Status Pill ───────────────────────────────────────────────────────────
function Improvement2() {
  const [idx, setIdx] = useState(1);
  const states = [
    { label: "READY",       color: "#22c55e", glow: "rgba(34,197,94,0.35)"   },
    { label: "LISTENING",   color: "#ef4444", glow: "rgba(239,68,68,0.35)"   },
    { label: "TRANSCRIBING",color: "#eab308", glow: "rgba(234,179,8,0.35)"   },
    { label: "ERROR",       color: "#f97316", glow: "rgba(249,115,22,0.35)"  },
  ];
  const s = states[idx];

  return (
    <ImprovementLayout
      number={2} title="Status Pill Redesign" tag="State Clarity"
      problem="Status text is plain monospaced with a thin colored border. All states look structurally identical — only text and color differ. The border is subtle and easy to overlook in peripheral vision."
      solution="A glowing capsule pill with a state-matched background tint, subtle inner border, and a pulsing dot for active states. The whole pill reads as 'active/inactive' instantly — no reading required."
      before={
        <MacPopover>
          <div style={{ padding: 24, display: "flex", flexDirection: "column", alignItems: "center", gap: 16 }}>
            <div style={{
              fontSize: 13, fontWeight: 600, color: s.color, fontFamily: "monospace",
              padding: "4px 14px", border: `1px solid ${s.color}`, borderRadius: 6, display: "inline-block",
            }}>{s.label}</div>
            <div style={{ display: "flex", gap: 5 }}>
              {states.map((st, i) => (
                <button key={i} onClick={() => setIdx(i)} style={{
                  width: 10, height: 10, borderRadius: "50%",
                  background: i === idx ? st.color : "rgba(255,255,255,0.15)",
                  border: "none", cursor: "pointer", padding: 0,
                }} />
              ))}
            </div>
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ padding: 24, display: "flex", flexDirection: "column", alignItems: "center", gap: 16 }}>
            <div style={{
              display: "inline-flex", alignItems: "center", gap: 8,
              padding: "8px 18px", borderRadius: 999,
              background: `${s.color}16`,
              border: `1px solid ${s.color}40`,
              boxShadow: `0 0 18px ${s.glow}, inset 0 1px 0 rgba(255,255,255,0.06)`,
              transition: "all 0.35s ease",
            }}>
              <span style={{
                width: 7, height: 7, borderRadius: "50%", background: s.color,
                boxShadow: `0 0 7px ${s.color}`,
                animation: idx === 1 || idx === 2 ? "pulse 1s ease-in-out infinite" : "none",
              }} />
              <span style={{
                fontSize: 11, fontWeight: 700, letterSpacing: "0.12em",
                color: s.color, fontFamily: "monospace",
              }}>{s.label}</span>
            </div>
            <div style={{ display: "flex", gap: 5 }}>
              {states.map((st, i) => (
                <button key={i} onClick={() => setIdx(i)} style={{
                  width: 10, height: 10, borderRadius: "50%",
                  background: i === idx ? st.color : "rgba(255,255,255,0.15)",
                  border: "none", cursor: "pointer", padding: 0, transition: "background 0.2s",
                }} />
              ))}
            </div>
            <div style={{ fontSize: 9, color: "rgba(255,255,255,0.2)" }}>Click dots to preview states</div>
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #3 History Cards ─────────────────────────────────────────────────────────
function Improvement3() {
  const items = [
    { time: "2:14 PM", text: "Send the quarterly report to the team by end of day Friday.", wpm: 142 },
    { time: "2:11 PM", text: "Schedule a call with the design team to review the new mockups.", wpm: 138 },
    { time: "2:08 PM", text: "Don't forget to update the changelog before pushing to main.", wpm: 156 },
  ];
  const [copiedIdx, setCopiedIdx] = useState<number | null>(null);

  return (
    <ImprovementLayout
      number={3} title="History Card Redesign" tag="Readability"
      problem="History items are flat cards: tiny timestamp + text. No WPM metadata, no visible copy affordance, no hover states. Items look static and unclickable. Scanning previous dictations requires reading every card top to bottom."
      solution="Left cyan accent stripe for visual anchoring, WPM badge next to the timestamp, hover border highlight, and an inline copy button with a green confirmation tick. Faster to scan, easier to act on."
      before={
        <MacPopover>
          <div style={{ padding: 14 }}>
            {items.map((item, i) => (
              <div key={i} style={{
                padding: "8px 10px", background: "rgba(255,255,255,0.04)",
                borderRadius: 8, border: "1px solid rgba(255,255,255,0.07)", marginBottom: 6,
              }}>
                <div style={{ fontSize: 9, color: "rgba(255,255,255,0.3)", marginBottom: 4 }}>{item.time}</div>
                <div style={{ fontSize: 11, color: "rgba(255,255,255,0.72)", lineHeight: 1.45 }}>{item.text}</div>
              </div>
            ))}
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ padding: 14 }}>
            {items.map((item, i) => (
              <div key={i} style={{
                padding: "10px 12px", paddingLeft: 14,
                background: "rgba(255,255,255,0.04)",
                borderRadius: 10, border: "1px solid rgba(255,255,255,0.07)",
                marginBottom: 6, position: "relative",
                transition: "border-color 0.2s", cursor: "default",
              }}
                onMouseEnter={e => (e.currentTarget.style.borderColor = "rgba(0,212,255,0.25)")}
                onMouseLeave={e => (e.currentTarget.style.borderColor = "rgba(255,255,255,0.07)")}
              >
                <div style={{
                  position: "absolute", left: 0, top: 8, bottom: 8,
                  width: 2, borderRadius: 2, background: "rgba(0,212,255,0.45)",
                }} />
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <span style={{ fontSize: 9, color: "rgba(255,255,255,0.28)" }}>{item.time}</span>
                    <span style={{
                      fontSize: 9, fontFamily: "monospace",
                      color: "rgba(0,212,255,0.65)", background: "rgba(0,212,255,0.08)",
                      border: "1px solid rgba(0,212,255,0.15)", borderRadius: 4, padding: "1px 5px",
                    }}>{item.wpm} wpm</span>
                  </div>
                  <button onClick={() => { setCopiedIdx(i); setTimeout(() => setCopiedIdx(null), 1500); }} style={{
                    fontSize: 9, color: copiedIdx === i ? "#22c55e" : "rgba(255,255,255,0.28)",
                    background: "transparent", border: "none", cursor: "pointer", padding: "2px 6px",
                    borderRadius: 4, transition: "color 0.2s",
                  }}>{copiedIdx === i ? "✓ copied" : "copy"}</button>
                </div>
                <div style={{ fontSize: 12, color: "rgba(255,255,255,0.82)", lineHeight: 1.5 }}>{item.text}</div>
              </div>
            ))}
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #4 Recording Mode ────────────────────────────────────────────────────────
function Improvement4() {
  const [active, setActive] = useState(false);
  const [bars, setBars] = useState(() => IDLE_RECORDING_BARS);
  const animRef = useRef<number>(0);

  useEffect(() => {
    if (!active) {
      return;
    }
    const frame = () => {
      setBars(prev => prev.map((_, i) =>
        Math.max(4, Math.round((Math.sin(Date.now() / 280 + i * 0.55) * 0.5 + 0.5 + Math.random() * 0.4) * 30))
      ));
      animRef.current = requestAnimationFrame(frame);
    };
    animRef.current = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(animRef.current);
  }, [active]);

  const displayedBars = active ? bars : IDLE_RECORDING_BARS;

  return (
    <ImprovementLayout
      number={4} title="Recording Mode Takeover" tag="Immersion"
      problem="While recording, the UI shows colored text ('LISTENING') and a red 'Turn Off Dictation' button. No visual transformation — the interface looks almost identical whether recording or idle. Easy to lose track of state."
      solution="Recording mode triggers a red-tinted card glow, a centered mic icon with pulse ring, and a live waveform inside the recording zone. The panel visually 'activates' when recording — impossible to miss."
      before={
        <MacPopover>
          <div style={{ padding: "20px 16px", textAlign: "center" }}>
            <div style={{ fontSize: 12, color: "#ef4444", fontFamily: "monospace", marginBottom: 10 }}>● LISTENING</div>
            <button style={{
              padding: "8px 20px", background: "rgba(239,68,68,0.12)",
              border: "1px solid rgba(239,68,68,0.35)", borderRadius: 8,
              color: "#ef4444", fontSize: 12, cursor: "pointer",
            }}>Turn Off Dictation</button>
          </div>
        </MacPopover>
      }
      after={
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
          <MacPopover>
            <div style={{
              padding: 20,
              background: active ? "linear-gradient(180deg, rgba(239,68,68,0.07) 0%, transparent 100%)" : "transparent",
              borderTop: active ? "1px solid rgba(239,68,68,0.18)" : "1px solid transparent",
              transition: "all 0.4s ease", textAlign: "center",
            }}>
              <div style={{
                width: 52, height: 52, borderRadius: "50%",
                background: active ? "rgba(239,68,68,0.14)" : "rgba(255,255,255,0.04)",
                border: `2px solid ${active ? "rgba(239,68,68,0.5)" : "rgba(255,255,255,0.12)"}`,
                boxShadow: active ? "0 0 28px rgba(239,68,68,0.28)" : "none",
                display: "flex", alignItems: "center", justifyContent: "center",
                margin: "0 auto 12px", fontSize: 22, cursor: "pointer", transition: "all 0.4s",
              }} onClick={() => setActive(!active)}>🎙</div>
              {active && (
                <div style={{ display: "flex", alignItems: "center", gap: 2, justifyContent: "center", height: 28, marginBottom: 8 }}>
                  {displayedBars.map((h, i) => (
                    <div key={i} style={{
                      width: 3.5, height: h, borderRadius: 2,
                      background: `rgba(239,68,68,${0.45 + (h / 32) * 0.5})`,
                      transition: "height 0.05s ease",
                    }} />
                  ))}
                </div>
              )}
              <div style={{
                fontSize: 11, fontWeight: 700, letterSpacing: "0.1em",
                color: active ? "#ef4444" : "rgba(255,255,255,0.3)",
                fontFamily: "monospace", transition: "color 0.3s",
                marginBottom: active ? 12 : 0,
              }}>{active ? "LISTENING..." : "IDLE — click mic"}</div>
              {active && (
                <button onClick={() => setActive(false)} style={{
                  padding: "6px 18px", background: "rgba(239,68,68,0.1)",
                  border: "1px solid rgba(239,68,68,0.28)", borderRadius: 20,
                  color: "rgba(239,68,68,0.8)", fontSize: 11, cursor: "pointer",
                }}>Stop</button>
              )}
            </div>
          </MacPopover>
          <div style={{ fontSize: 10, color: "rgba(255,255,255,0.2)" }}>Click the mic icon to toggle</div>
        </div>
      }
    />
  );
}

// ─── #5 Empty State ───────────────────────────────────────────────────────────
function Improvement5() {
  return (
    <ImprovementLayout
      number={5} title="Empty State Design" tag="Guidance"
      problem="The history empty state is a single centered gray line: 'No transcription history yet.' No icon, no CTA, no shortcut hint. First-time users stare at a blank panel with no signal about what to do next."
      solution="An empty state with a dashed mic icon container, a descriptive headline, a cyan action hint, and a keyboard shortcut badge. Guides the user to their first transcription without needing to explore settings."
      before={
        <MacPopover>
          <div style={{ padding: "28px 16px", textAlign: "center" }}>
            <div style={{ fontSize: 11, color: "rgba(255,255,255,0.3)" }}>No transcription history yet</div>
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ padding: "24px 20px", textAlign: "center", display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
            <div style={{
              width: 48, height: 48, borderRadius: 14,
              background: "rgba(255,255,255,0.03)",
              border: "1px dashed rgba(255,255,255,0.15)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 22, color: "rgba(255,255,255,0.22)",
            }}>🎙</div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: "rgba(255,255,255,0.55)", marginBottom: 5 }}>Nothing transcribed yet</div>
              <div style={{ fontSize: 11, color: "rgba(255,255,255,0.3)", lineHeight: 1.6 }}>
                Press your shortcut or click<br />
                <span style={{ color: "rgba(0,212,255,0.65)" }}>Start Dictation</span> below to begin
              </div>
            </div>
            <div style={{
              display: "flex", alignItems: "center", gap: 6, marginTop: 4,
              padding: "5px 12px",
              background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 8,
            }}>
              <kbd style={{
                fontSize: 10, fontFamily: "monospace",
                background: "rgba(255,255,255,0.07)", border: "1px solid rgba(255,255,255,0.12)",
                borderRadius: 4, padding: "2px 7px", color: "rgba(255,255,255,0.45)",
              }}>⌥ F9</kbd>
              <span style={{ fontSize: 10, color: "rgba(255,255,255,0.22)" }}>trigger dictation</span>
            </div>
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #6 Settings Layout ───────────────────────────────────────────────────────
function Improvement6() {
  const [open, setOpen] = useState<string | null>("Output");
  const sections = [
    { icon: "⚡", label: "Mode", items: ["Profile: Standard", "Flavor Ticker", "Stats Ticker"] },
    { icon: "🔊", label: "Sound", items: ["Start sound: Chirp", "Stop sound: Pop"] },
    { icon: "📤", label: "Output", items: ["Safe Mode: OFF", "Auto-Paste: ON", "Profanity Filter", "Accessibility API", "Per-App Rules"] },
    { icon: "🖥", label: "System", items: ["Launch at Login", "Menu Bar Style"] },
    { icon: "🎛", label: "Input", items: ["Microphone: Built-in", "Silence Timeout: 1.5s"] },
  ];

  return (
    <ImprovementLayout
      number={6} title="Settings Panel Layout" tag="Organization"
      problem="The settings panel is 1,100+ lines of a flat vertical list separated only by horizontal rules and text labels. No visual hierarchy — beginners and power users see the same wall of options, causing cognitive overload."
      solution="Accordion sections with icon labels and a cyan left-border on expanded content. Each header is visually distinct with an icon, and sections collapse to just their title. Beginners see five clean labels; power users expand what they need."
      before={
        <MacPopover>
          <div style={{ maxHeight: 250, overflowY: "auto", padding: "8px 12px" }}>
            {[
              "─── Mode ──────────────────",
              "  Profile: Standard",
              "  Flavor Ticker",
              "─── Feedback ─────────────",
              "  Start sound",
              "  Stop sound",
              "─── Output ───────────────",
              "  Safe Mode: OFF",
              "  Auto-Paste: ON",
              "  Profanity Filter",
              "  Accessibility API",
              "─── System ───────────────",
              "  Launch at Login",
              "─── Benchmark ────────────",
              "  Model selection",
              "  Optimization",
            ].map((line, i) => (
              <div key={i} style={{
                fontSize: line.startsWith("─") ? 9 : 11,
                color: line.startsWith("─") ? "rgba(255,255,255,0.25)" : "rgba(255,255,255,0.6)",
                fontFamily: line.startsWith("─") ? "monospace" : "inherit",
                padding: "3px 0",
              }}>{line}</div>
            ))}
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ maxHeight: 250, overflowY: "auto" }}>
            <div style={{
              display: "flex", alignItems: "center", gap: 8,
              padding: "10px 12px 8px", borderBottom: "1px solid rgba(255,255,255,0.06)",
            }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: "rgba(255,255,255,0.55)", letterSpacing: "0.1em", textTransform: "uppercase" as const }}>Settings</span>
            </div>
            {sections.map(sec => (
              <div key={sec.label}>
                <button onClick={() => setOpen(open === sec.label ? null : sec.label)} style={{
                  width: "100%", display: "flex", alignItems: "center", gap: 8,
                  padding: "8px 12px",
                  background: open === sec.label ? "rgba(0,212,255,0.055)" : "transparent",
                  border: "none", cursor: "pointer", textAlign: "left" as const, transition: "background 0.15s",
                }}>
                  <span style={{ fontSize: 14 }}>{sec.icon}</span>
                  <span style={{ fontSize: 11.5, fontWeight: 500, color: open === sec.label ? "#fff" : "rgba(255,255,255,0.58)", flex: 1 }}>{sec.label}</span>
                  <span style={{
                    fontSize: 10, color: "rgba(255,255,255,0.22)",
                    display: "inline-block", transition: "transform 0.2s",
                    transform: open === sec.label ? "rotate(90deg)" : "none",
                  }}>›</span>
                </button>
                {open === sec.label && (
                  <div style={{ paddingLeft: 36, paddingBottom: 4, marginLeft: 20, borderLeft: "2px solid rgba(0,212,255,0.18)" }}>
                    {sec.items.map((item, j) => (
                      <div key={j} style={{ fontSize: 11, color: "rgba(255,255,255,0.45)", padding: "4px 8px" }}>{item}</div>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #7 Floating HUD ──────────────────────────────────────────────────────────
function Improvement7() {
  const [idx, setIdx] = useState(1);
  const states = [
    { label: "IDLE",         color: "rgba(255,255,255,0.3)", glow: "transparent", bar: 0 },
    { label: "LISTENING",    color: "#ef4444",               glow: "rgba(239,68,68,0.2)", bar: 0 },
    { label: "TRANSCRIBING", color: "#eab308",               glow: "rgba(234,179,8,0.2)", bar: 1 },
    { label: "READY",        color: "#22c55e",               glow: "rgba(34,197,94,0.2)", bar: 0 },
  ];
  const s = states[idx];
  const [bars, setBars] = useState(() => IDLE_HUD_BARS);
  const animRef = useRef<number>(0);

  useEffect(() => {
    if (idx !== 1) {
      return;
    }
    const frame = () => {
      setBars(prev => prev.map((_, i) =>
        Math.max(3, Math.round((Math.sin(Date.now() / 230 + i * 0.85) * 0.5 + 0.5 + Math.random() * 0.3) * 14))
      ));
      animRef.current = requestAnimationFrame(frame);
    };
    animRef.current = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(animRef.current);
  }, [idx]);

  const displayedBars = idx === 1 ? bars : IDLE_HUD_BARS;

  return (
    <ImprovementLayout
      number={7} title="Floating HUD Redesign" tag="Always-On UI"
      problem="The 200×60px HUD shows a text label, a 3px progress bar, and a barely-visible 'DEX' watermark. All states look nearly identical — only the text changes. It's static and easy to ignore as visual noise."
      solution="State-reactive border glow, a live waveform for LISTENING, a shimmer sweep for TRANSCRIBING, and a clean typography layout. The HUD communicates its state through motion and color — not just text."
      before={
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
          <div style={{
            width: 200, height: 60,
            background: "rgba(0,0,0,0.82)", border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: 10, display: "flex", alignItems: "center", padding: "0 10px", gap: 8,
          }}>
            <span style={{ fontSize: 10, color: s.color, fontFamily: "monospace", fontWeight: 700, whiteSpace: "nowrap" as const }}>
              {idx === 1 ? "●" : "◦"} {s.label}
            </span>
            <div style={{ flex: 1, height: 3, background: "rgba(255,255,255,0.07)", borderRadius: 2 }}>
              {idx === 2 && <div style={{ height: "100%", width: "55%", background: s.color, borderRadius: 2 }} />}
            </div>
            <span style={{ fontSize: 8, color: "rgba(255,255,255,0.1)", fontFamily: "monospace" }}>DEX</span>
          </div>
          <StateButtons states={states} activeIndex={idx} onSelect={setIdx} />
        </div>
      }
      after={
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
          <div style={{
            width: 220,
            background: "rgba(10,10,18,0.94)", backdropFilter: "blur(20px)",
            border: `1px solid ${s.color}35`,
            borderRadius: 12, padding: "10px 14px",
            boxShadow: `0 8px 32px rgba(0,0,0,0.5), 0 0 20px ${s.glow}`,
            transition: "border-color 0.4s, box-shadow 0.4s",
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: idx === 1 ? 6 : 0 }}>
              <div style={{
                width: 7, height: 7, borderRadius: "50%", background: s.color,
                boxShadow: `0 0 8px ${s.color}90`, flexShrink: 0,
                animation: idx === 1 ? "pulse 1s ease-in-out infinite" : "none",
              }} />
              <span style={{ fontSize: 10, fontWeight: 700, color: s.color, fontFamily: "monospace", letterSpacing: "0.08em" }}>{s.label}</span>
              <span style={{ marginLeft: "auto", fontSize: 9, color: "rgba(255,255,255,0.15)", fontWeight: 700, fontFamily: "monospace" }}>DEXDICTATE</span>
            </div>
            {idx === 1 && (
              <div style={{ display: "flex", alignItems: "center", gap: 2, height: 14 }}>
                {displayedBars.map((h, i) => (
                  <div key={i} style={{
                    flex: 1, height: h, borderRadius: 1.5,
                    background: `rgba(239,68,68,${0.35 + (h / 16) * 0.55})`,
                    transition: "height 0.05s ease",
                  }} />
                ))}
              </div>
            )}
            {idx === 2 && (
              <div style={{ height: 3, background: "rgba(255,255,255,0.05)", borderRadius: 2, overflow: "hidden" }}>
                <div style={{
                  height: "100%", width: "35%",
                  background: `linear-gradient(90deg, transparent, #eab308, transparent)`,
                  animation: "shimmer 1.2s ease-in-out infinite",
                }} />
              </div>
            )}
          </div>
          <StateButtons states={states} activeIndex={idx} onSelect={setIdx} />
        </div>
      }
    />
  );
}

// ─── #8 Onboarding Flow ───────────────────────────────────────────────────────
function Improvement8() {
  const [step, setStep] = useState(0);
  const steps = ["Welcome", "Permissions", "Shortcut", "Done"];
  const icons = ["🎙", "🔒", "⌨️", "✅"];
  const headlines = ["Welcome to DexDictate", "Grant Permissions", "Set Your Shortcut", "You're All Set!"];
  const descs = [
    "Fast, private voice dictation right in your menu bar.",
    "Microphone & accessibility access are required to operate.",
    "Pick any key combo — you can change it later in settings.",
    "DexDictate is ready. Press your shortcut to start dictating.",
  ];

  return (
    <ImprovementLayout
      number={8} title="Onboarding Step Progress" tag="First-Run UX"
      problem="Onboarding navigation is plain 'Page X of 4' text. Users have no sense of what's coming, can't jump to a specific step, and don't see overall progress. Steps feel disconnected and the flow feels long."
      solution="A connected step rail with numbered circles, green checkmarks for completed steps, and labels. Active step glows cyan, completed steps turn green, the rail fills progressively. Click any step to jump. Interactive preview below."
      before={
        <MacPopover width={300}>
          <div style={{ padding: "24px 20px", textAlign: "center" }}>
            <div style={{ fontSize: 10, color: "rgba(255,255,255,0.3)", marginBottom: 14 }}>Page {step + 1} of 4</div>
            <div style={{ fontSize: 14, fontWeight: 700, color: "#fff", marginBottom: 8 }}>{headlines[step]}</div>
            <div style={{ fontSize: 11, color: "rgba(255,255,255,0.4)", lineHeight: 1.6, marginBottom: 20 }}>{descs[step]}</div>
            <div style={{ display: "flex", gap: 8 }}>
              {step > 0 && (
                <button onClick={() => setStep(step - 1)} style={{
                  flex: 1, padding: "8px", background: "rgba(255,255,255,0.05)",
                  border: "1px solid rgba(255,255,255,0.1)", borderRadius: 7,
                  color: "rgba(255,255,255,0.5)", fontSize: 11, cursor: "pointer",
                }}>Back</button>
              )}
              <button onClick={() => step < 3 && setStep(step + 1)} style={{
                flex: 2, padding: "8px",
                background: step === 3 ? "rgba(34,197,94,0.14)" : "rgba(0,212,255,0.1)",
                border: `1px solid ${step === 3 ? "rgba(34,197,94,0.3)" : "rgba(0,212,255,0.25)"}`,
                borderRadius: 7,
                color: step === 3 ? "#22c55e" : "#00d4ff",
                fontSize: 11, cursor: "pointer",
              }}>{step === 3 ? "Get Started" : "Next"}</button>
            </div>
          </div>
        </MacPopover>
      }
      after={
        <MacPopover width={320}>
          <div style={{ padding: "20px 18px" }}>
            {/* Step rail */}
            <div style={{ display: "flex", alignItems: "center", marginBottom: 20 }}>
              {steps.map((label, i) => (
                <div key={i} style={{ display: "flex", alignItems: "center", flex: i < steps.length - 1 ? 1 : 0 }}>
                  <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
                    <div onClick={() => setStep(i)} style={{
                      width: 26, height: 26, borderRadius: "50%", cursor: "pointer",
                      background: i < step ? "#22c55e" : i === step ? "rgba(0,212,255,0.18)" : "rgba(255,255,255,0.04)",
                      border: `2px solid ${i < step ? "#22c55e" : i === step ? "#00d4ff" : "rgba(255,255,255,0.1)"}`,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 10, fontWeight: 700,
                      color: i < step ? "#fff" : i === step ? "#00d4ff" : "rgba(255,255,255,0.22)",
                      transition: "all 0.3s",
                    }}>{i < step ? "✓" : i + 1}</div>
                    <div style={{
                      fontSize: 8.5, marginTop: 4, whiteSpace: "nowrap" as const,
                      color: i === step ? "#00d4ff" : "rgba(255,255,255,0.22)",
                      fontWeight: i === step ? 600 : 400,
                    }}>{label}</div>
                  </div>
                  {i < steps.length - 1 && (
                    <div style={{
                      flex: 1, height: 2, marginBottom: 14, marginLeft: 5, marginRight: 5,
                      background: i < step ? "#22c55e" : "rgba(255,255,255,0.07)",
                      borderRadius: 1, transition: "background 0.35s",
                    }} />
                  )}
                </div>
              ))}
            </div>
            {/* Content */}
            <div style={{
              background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)",
              borderRadius: 12, padding: "18px 16px", marginBottom: 14,
              textAlign: "center", minHeight: 90,
              display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 7,
            }}>
              <div style={{ fontSize: 26 }}>{icons[step]}</div>
              <div style={{ fontSize: 14, fontWeight: 700, color: "#fff" }}>{headlines[step]}</div>
              <div style={{ fontSize: 11, color: "rgba(255,255,255,0.4)", lineHeight: 1.6 }}>{descs[step]}</div>
            </div>
            <div style={{ display: "flex", gap: 8 }}>
              {step > 0 && (
                <button onClick={() => setStep(step - 1)} style={{
                  flex: 1, padding: "9px",
                  background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.09)",
                  borderRadius: 8, color: "rgba(255,255,255,0.45)", fontSize: 12, cursor: "pointer",
                }}>← Back</button>
              )}
              <button onClick={() => step < 3 && setStep(step + 1)} style={{
                flex: 2, padding: "9px",
                background: step === 3 ? "rgba(34,197,94,0.12)" : "rgba(0,212,255,0.1)",
                border: `1px solid ${step === 3 ? "rgba(34,197,94,0.3)" : "rgba(0,212,255,0.22)"}`,
                borderRadius: 8,
                color: step === 3 ? "#22c55e" : "#00d4ff",
                fontSize: 12, fontWeight: 600, cursor: "pointer",
              }}>{step === 3 ? "Start Dictating →" : "Continue →"}</button>
            </div>
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #9 Quick Action Bar ──────────────────────────────────────────────────────
function Improvement9() {
  const [feedback, setFeedback] = useState<number | null>(null);
  const actions = [
    { icon: "🎙", label: "Start",    color: "#22c55e", msg: "Starting dictation session..." },
    { icon: "📂", label: "Import",   color: "#22d3ee", msg: "Opening file picker..."        },
    { icon: "📋", label: "Copy Last",color: "#a78bfa", msg: "Last transcript copied!"       },
    { icon: "🗑", label: "Clear",    color: "#f87171", msg: "History cleared."              },
    { icon: "⚙️", label: "Settings", color: "#94a3b8", msg: "Opening settings..."           },
  ];

  return (
    <ImprovementLayout
      number={9} title="Quick Action Bar" tag="Efficiency"
      problem="Primary actions are full-width stacked text buttons. Scanning them requires reading each label on every visit. Import and Copy Last — frequently used — are buried in the same visual weight as the Quit button."
      solution="A horizontal tile grid: icon above label, all 5 actions visible at once in less vertical space than 2 old buttons. Tapping shows a one-line feedback strip. More efficient to scan and act on."
      before={
        <MacPopover>
          <div style={{ padding: "12px 14px", display: "flex", flexDirection: "column", gap: 6 }}>
            {[
              { label: "Start Dictation", c: "#22c55e" },
              { label: "Transcribe File...", c: "#22d3ee" },
              { label: "Quit App", c: "rgba(255,255,255,0.4)" },
            ].map((b, i) => (
              <button key={i} style={{
                width: "100%", padding: "8px", borderRadius: 8, cursor: "pointer",
                background: `${b.c}14`, border: `1px solid ${b.c}35`, color: b.c, fontSize: 12,
              }}>{b.label}</button>
            ))}
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ padding: "12px 14px" }}>
            <div style={{ display: "flex", gap: 5, marginBottom: 6 }}>
              {actions.map((a, i) => (
                <button key={i} onClick={() => { setFeedback(i); setTimeout(() => setFeedback(null), 1800); }} style={{
                  flex: 1, padding: "9px 4px",
                  background: feedback === i ? `${a.color}1a` : "rgba(255,255,255,0.04)",
                  border: `1px solid ${feedback === i ? `${a.color}45` : "rgba(255,255,255,0.08)"}`,
                  borderRadius: 9, cursor: "pointer",
                  display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
                  transition: "all 0.15s",
                }}>
                  <span style={{ fontSize: 15 }}>{a.icon}</span>
                  <span style={{
                    fontSize: 8.5, fontWeight: 600, letterSpacing: "0.03em",
                    color: feedback === i ? a.color : "rgba(255,255,255,0.32)",
                    transition: "color 0.15s",
                  }}>{a.label}</span>
                </button>
              ))}
            </div>
            {feedback !== null ? (
              <div style={{
                padding: "7px 10px", borderRadius: 8,
                background: `${actions[feedback].color}0f`,
                border: `1px solid ${actions[feedback].color}28`,
                fontSize: 11, color: actions[feedback].color, textAlign: "center",
              }}>{actions[feedback].msg}</div>
            ) : (
              <div style={{ height: 32, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontSize: 9, color: "rgba(255,255,255,0.18)" }}>Tap an action above</span>
              </div>
            )}
          </div>
        </MacPopover>
      }
    />
  );
}

// ─── #10 Color System ─────────────────────────────────────────────────────────
function Improvement10() {
  const oldColors = [
    { name: "Listening",    raw: "rgba(255,0,0,1)",     note: "pure red #FF0000"   },
    { name: "Ready",        raw: "rgba(0,255,0,1)",     note: "pure green #00FF00" },
    { name: "Transcribing", raw: "rgba(255,255,0,1)",   note: "pure yellow #FFFF00"},
    { name: "Warning",      raw: "rgba(255,165,0,1)",   note: "pure orange #FFA500"},
    { name: "Accent",       raw: "rgba(0,255,255,1)",   note: "pure cyan #00FFFF"  },
  ];
  const newColors = [
    { name: "Listening",    value: "#ef4444", bg: "rgba(239,68,68,0.1)",   border: "rgba(239,68,68,0.28)",  note: "red-500"    },
    { name: "Ready",        value: "#22c55e", bg: "rgba(34,197,94,0.1)",   border: "rgba(34,197,94,0.28)",  note: "green-500"  },
    { name: "Transcribing", value: "#eab308", bg: "rgba(234,179,8,0.1)",   border: "rgba(234,179,8,0.28)",  note: "yellow-500" },
    { name: "Warning",      value: "#f97316", bg: "rgba(249,115,22,0.1)",  border: "rgba(249,115,22,0.28)", note: "orange-500" },
    { name: "Accent",       value: "#22d3ee", bg: "rgba(34,211,238,0.1)",  border: "rgba(34,211,238,0.28)", note: "cyan-400"   },
  ];

  return (
    <ImprovementLayout
      number={10} title="Semantic Color System" tag="Consistency"
      problem="Status colors use full-saturation values: pure red, pure green, pure yellow. Against a dark translucent glass background these are eye-searing — they glow harshly and feel like debug markers, not a polished product."
      solution="Adopt Tailwind's semantic palette. Each color gets a tinted background swatch + calibrated border opacity, so pills, badges, and card borders all share a consistent tinting language that reads as 'premium dark UI'."
      before={
        <MacPopover>
          <div style={{ padding: "14px 16px" }}>
            <div style={{ fontSize: 9, color: "rgba(255,255,255,0.25)", marginBottom: 10, fontFamily: "monospace" }}>Pure / full-saturation colors</div>
            {oldColors.map((c, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
                <div style={{ width: 24, height: 24, borderRadius: 5, background: c.raw, flexShrink: 0 }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 11, color: "rgba(255,255,255,0.65)" }}>{c.name}</div>
                  <div style={{ fontSize: 9, fontFamily: "monospace", color: "rgba(255,255,255,0.28)" }}>{c.note}</div>
                </div>
                <div style={{
                  padding: "3px 10px", borderRadius: 4,
                  background: c.raw.replace(", 1)", ", 0.15)"),
                  border: `1px solid ${c.raw.replace(", 1)", ", 0.6)")}`,
                  fontSize: 10, color: c.raw,
                }}>{c.name}</div>
              </div>
            ))}
          </div>
        </MacPopover>
      }
      after={
        <MacPopover>
          <div style={{ padding: "14px 16px" }}>
            <div style={{ fontSize: 9, color: "rgba(255,255,255,0.25)", marginBottom: 10, fontFamily: "monospace" }}>Calibrated Tailwind semantic palette</div>
            {newColors.map((c, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
                <div style={{
                  width: 24, height: 24, borderRadius: 5, flexShrink: 0,
                  background: c.bg, border: `1px solid ${c.border}`,
                  display: "flex", alignItems: "center", justifyContent: "center",
                }}>
                  <div style={{ width: 9, height: 9, borderRadius: "50%", background: c.value }} />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 11, color: "rgba(255,255,255,0.65)" }}>{c.name}</div>
                  <div style={{ fontSize: 9, fontFamily: "monospace", color: "rgba(255,255,255,0.28)" }}>{c.note}</div>
                </div>
                <div style={{
                  padding: "4px 12px", borderRadius: 999,
                  background: c.bg, border: `1px solid ${c.border}`,
                  fontSize: 10, fontWeight: 600, color: c.value,
                  boxShadow: `0 0 8px ${c.bg}`,
                }}>{c.name}</div>
              </div>
            ))}
          </div>
        </MacPopover>
      }
    />
  );
}
