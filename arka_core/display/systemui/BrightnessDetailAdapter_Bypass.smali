import { useState, useRef, useCallback, useMemo } from "react";

// ─── Data ────────────────────────────────────────────────────────────────────

const SMALI_SECTIONS = [
  {
    id: "header",
    label: "Class Header",
    icon: "⬡",
    color: "#60efff",
    lines: [
      { type: "directive", text: ".class public final Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;" },
      { type: "directive", text: ".super Ljava/lang/Object;" },
      { type: "comment",   text: ".source \"BrightnessDetailAdapter.kt\"" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "# interfaces" },
      { type: "directive", text: ".implements Lcom/android/systemui/plugins/qs/DetailAdapter;" },
    ],
  },
  {
    id: "fields",
    label: "Instance Fields",
    icon: "◈",
    color: "#a78bfa",
    lines: [
      { type: "comment",   text: "# Static fields" },
      { type: "directive", text: ".field public static final synthetic $r8$clinit:I" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "# Instance fields" },
      { type: "directive", text: ".field public final activityStarter$delegate:Lkotlin/Lazy;" },
      { type: "directive", text: ".field public autoBrightnessContainer:Lcom/android/systemui/qs/SecQSSwitchPreference;" },
      { type: "directive", text: ".field public final autoBrightnessDelegate:Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$autoBrightnessDelegate$1;" },
      { type: "directive", text: ".field public autoBrightnessSummary:Landroid/widget/TextView;" },
      { type: "directive", text: ".field public autoBrightnessSwitch:Landroidx/appcompat/widget/SwitchCompat;" },
      { type: "directive", text: ".field public brightnessController:Lcom/android/systemui/settings/brightness/BrightnessController;" },
      { type: "directive", text: ".field public brightnessObserver:Lcom/android/systemui/settings/brightness/BrightnessObserver;" },
      { type: "directive", text: ".field public final context:Landroid/content/Context;" },
      { type: "directive", text: ".field public enforcedAdmin:Lcom/android/settingslib/RestrictedLockUtils$EnforcedAdmin;" },
      { type: "directive", text: ".field public final factory:Lcom/android/systemui/settings/brightness/BrightnessController$Factory;" },
      { type: "directive", text: ".field public final quickBarBrightnessExtraBrightness:Lcom/android/systemui/settings/brightness/QuickBarBrightnessExtraBrightness;" },
      { type: "directive", text: ".field public final quickKnox:Lcom/android/systemui/knox/KnoxStateMonitor;" },
      { type: "directive", text: ".field public final quickSALog:Lcom/android/systemui/settings/brightness/QuickSALog;" },
      { type: "directive", text: ".field public final sensorPrivacyManager$delegate:Lkotlin/Lazy;" },
    ],
  },
  {
    id: "clinit",
    label: "<clinit>",
    icon: "⚙",
    color: "#34d399",
    lines: [
      { type: "directive", text: ".method static constructor <clinit>()V" },
      { type: "indent",    text: "    .locals 2" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Init Companion object" },
      { type: "opcode",    text: "    new-instance v0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$Companion;" },
      { type: "opcode",    text: "    const/4 v1, 0x0" },
      { type: "opcode",    text: "    invoke-direct {v0, v1}, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$Companion;-><init>(Lkotlin/jvm/internal/DefaultConstructorMarker;)V" },
      { type: "opcode",    text: "    return-void" },
      { type: "directive", text: ".end method" },
    ],
  },
  {
    id: "init",
    label: "Constructor <init>",
    icon: "◎",
    color: "#f472b6",
    lines: [
      { type: "directive", text: ".method public constructor <init>(Landroid/content/Context;Lcom/android/systemui/settings/brightness/BrightnessController$Factory;)V" },
      { type: "indent",    text: "    .locals 0" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Call Object.<init>" },
      { type: "opcode",    text: "    invoke-direct {p0}, Ljava/lang/Object;-><init>()V" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Store context and factory" },
      { type: "opcode",    text: "    iput-object p1, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->context:Landroid/content/Context;" },
      { type: "opcode",    text: "    iput-object p2, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->factory:Lcom/android/systemui/settings/brightness/BrightnessController$Factory;" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Conditionally create QuickBarBrightnessExtraBrightness if feature flag set" },
      { type: "opcode",    text: "    sget-boolean p2, Lcom/android/systemui/QpRune;->QUICK_BAR_BRIGHTNESS_EXTRA_BRIGHTNESS:Z" },
      { type: "label",     text: "    if-eqz p2, :cond_no_extra_brightness" },
      { type: "opcode",    text: "    new-instance p2, Lcom/android/systemui/settings/brightness/QuickBarBrightnessExtraBrightness;" },
      { type: "opcode",    text: "    invoke-direct {p2, p1}, Lcom/android/systemui/settings/brightness/QuickBarBrightnessExtraBrightness;-><init>(Landroid/content/Context;)V" },
      { type: "label",     text: "    goto :goto_store_extra_brightness" },
      { type: "label",     text: "    :cond_no_extra_brightness" },
      { type: "opcode",    text: "    const/4 p2, 0x0" },
      { type: "label",     text: "    :goto_store_extra_brightness" },
      { type: "opcode",    text: "    iput-object p2, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->quickBarBrightnessExtraBrightness:Lcom/android/systemui/settings/brightness/QuickBarBrightnessExtraBrightness;" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Create QuickSALog" },
      { type: "opcode",    text: "    new-instance p2, Lcom/android/systemui/settings/brightness/QuickSALog;" },
      { type: "opcode",    text: "    invoke-direct {p2, p1}, Lcom/android/systemui/settings/brightness/QuickSALog;-><init>(Landroid/content/Context;)V" },
      { type: "opcode",    text: "    iput-object p2, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->quickSALog:Lcom/android/systemui/settings/brightness/QuickSALog;" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Lazy-initialise activityStarter (index 0)" },
      { type: "opcode",    text: "    new-instance p1, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$$ExternalSyntheticLambda0;" },
      { type: "opcode",    text: "    const/4 p2, 0x0" },
      { type: "opcode",    text: "    invoke-direct {p1, p2}, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$$ExternalSyntheticLambda0;-><init>(I)V" },
      { type: "opcode",    text: "    invoke-static {p1}, Lkotlin/LazyKt__LazyJVMKt;->lazy(Lkotlin/jvm/functions/Function0;)Lkotlin/Lazy;" },
      { type: "opcode",    text: "    move-result-object p1" },
      { type: "opcode",    text: "    iput-object p1, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->activityStarter$delegate:Lkotlin/Lazy;" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Lazy-initialise sensorPrivacyManager (index 1)" },
      { type: "opcode",    text: "    new-instance p1, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$$ExternalSyntheticLambda0;" },
      { type: "opcode",    text: "    const/4 p2, 0x1" },
      { type: "opcode",    text: "    invoke-direct {p1, p2}, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$$ExternalSyntheticLambda0;-><init>(I)V" },
      { type: "opcode",    text: "    invoke-static {p1}, Lkotlin/LazyKt__LazyJVMKt;->lazy(Lkotlin/jvm/functions/Function0;)Lkotlin/Lazy;" },
      { type: "opcode",    text: "    move-result-object p1" },
      { type: "opcode",    text: "    iput-object p1, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->sensorPrivacyManager$delegate:Lkotlin/Lazy;" },
      { type: "opcode",    text: "    return-void" },
      { type: "directive", text: ".end method" },
    ],
  },
  {
    id: "setBrightness",
    label: "setBrightness",
    icon: "☀",
    color: "#fbbf24",
    lines: [
      { type: "directive", text: ".method public static final access$setBrightness(Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;ZZ)V" },
      { type: "indent",    text: "    .locals 7" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Check Knox brightness block" },
      { type: "opcode",    text: "    iget-object v0, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->quickKnox:Lcom/android/systemui/knox/KnoxStateMonitor;" },
      { type: "opcode",    text: "    const/4 v1, 0x0" },
      { type: "label",     text: "    if-eqz v0, :cond_knox_null" },
      { type: "opcode",    text: "    check-cast v0, Lcom/android/systemui/knox/KnoxStateMonitorImpl;" },
      { type: "opcode",    text: "    invoke-virtual {v0}, Lcom/android/systemui/knox/KnoxStateMonitorImpl;->isBrightnessBlocked()Z" },
      { type: "opcode",    text: "    move-result v0" },
      { type: "opcode",    text: "    invoke-static {v0}, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;" },
      { type: "opcode",    text: "    move-result-object v0" },
      { type: "label",     text: "    goto :goto_knox_check" },
      { type: "label",     text: "    :cond_knox_null" },
      { type: "opcode",    text: "    move-object v0, v1" },
      { type: "label",     text: "    :goto_knox_check" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Knox is blocking brightness — log and force manual mode" },
      { type: "label",     text: "    if-eqz v0, :cond_knox_not_blocked" },
      { type: "opcode",    text: "    const-string v0, \"Auto brightness options are not available by KnoxStateMonitor.\"" },
      { type: "opcode",    text: "    invoke-static {v2, v0}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I" },
      { type: "label",     text: "    goto :goto_after_knox" },
      { type: "label",     text: "    :cond_knox_not_blocked" },
      { type: "opcode",    text: "    move p1, p2" },
      { type: "label",     text: "    :goto_after_knox" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Write screen_brightness_mode or display_outdoor_mode based on light sensor support" },
      { type: "opcode",    text: "    invoke-static {v0}, Lcom/android/systemui/util/DeviceType;->isLightSensorSupported(Landroid/content/Context;)Z" },
      { type: "label",     text: "    if-eqz v2, :cond_no_light_sensor" },
      { type: "opcode",    text: "    invoke-static {v0, v2, p1, v3}, Landroid/provider/Settings$System;->putIntForUser(Landroid/content/ContentResolver;Ljava/lang/String;II)Z" },
      { type: "label",     text: "    goto :goto_5" },
      { type: "label",     text: "    :cond_no_light_sensor" },
      { type: "opcode",    text: "    invoke-static {v0, v2, p1, v3}, Landroid/provider/Settings$System;->putIntForUser(Landroid/content/ContentResolver;Ljava/lang/String;II)Z" },
      { type: "label",     text: "    :goto_5" },
      { type: "opcode",    text: "    return-void" },
      { type: "directive", text: ".end method" },
    ],
  },
  {
    id: "createDetailView",
    label: "createDetailView",
    icon: "⬢",
    color: "#38bdf8",
    lines: [
      { type: "directive", text: ".method public final createDetailView(Landroid/content/Context;Landroid/view/View;Landroid/view/ViewGroup;)Landroid/view/View;" },
      { type: "indent",    text: "    .locals 12" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Guard: return empty View if convertView is null" },
      { type: "opcode",    text: "    const/4 p2, 0x0" },
      { type: "label",     text: "    if-nez p1, :cond_0" },
      { type: "opcode",    text: "    new-instance p0, Landroid/view/View;" },
      { type: "opcode",    text: "    invoke-direct {p0, p2}, Landroid/view/View;-><init>(Landroid/content/Context;)V" },
      { type: "opcode",    text: "    return-object p0" },
      { type: "blank",     text: "" },
      { type: "label",     text: "    :cond_0" },
      { type: "comment",   text: "    # Inflate brightness detail layout" },
      { type: "opcode",    text: "    invoke-static {p1}, Landroid/view/LayoutInflater;->from(Landroid/content/Context;)Landroid/view/LayoutInflater;" },
      { type: "opcode",    text: "    move-result-object v0" },
      { type: "opcode",    text: "    const v1, 0x7f0d039b" },
      { type: "opcode",    text: "    const/4 v2, 0x0" },
      { type: "opcode",    text: "    invoke-virtual {v0, v1, p3, v2}, Landroid/view/LayoutInflater;->inflate(ILandroid/view/ViewGroup;Z)Landroid/view/View;" },
      { type: "opcode",    text: "    move-result-object p3" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Inflate auto-brightness switch row" },
      { type: "opcode",    text: "    invoke-static {p1, v0}, Lcom/android/systemui/qs/SecQSSwitchPreference;->inflateSwitch(Landroid/content/Context;Landroid/view/ViewGroup;)Lcom/android/systemui/qs/SecQSSwitchPreference;" },
      { type: "opcode",    text: "    move-result-object v1" },
      { type: "opcode",    text: "    iput-object v1, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->autoBrightnessContainer:Lcom/android/systemui/qs/SecQSSwitchPreference;" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Set title based on light sensor availability" },
      { type: "opcode",    text: "    invoke-static {p1}, Lcom/android/systemui/util/DeviceType;->isLightSensorSupported(Landroid/content/Context;)Z" },
      { type: "opcode",    text: "    move-result v1" },
      { type: "label",     text: "    if-eqz v1, :cond_1" },
      { type: "opcode",    text: "    const v1, 0x7f1311e8    # string: auto_brightness_label" },
      { type: "label",     text: "    goto :goto_0" },
      { type: "label",     text: "    :cond_1" },
      { type: "opcode",    text: "    const v1, 0x7f1311f3    # string: outdoor_mode_label" },
      { type: "label",     text: "    :goto_0" },
      { type: "blank",     text: "" },
      { type: "comment",   text: "    # Attach attach-state listener for controller lifecycle" },
      { type: "opcode",    text: "    new-instance p2, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$createDetailView$1$2;" },
      { type: "opcode",    text: "    invoke-direct {p2, p0, p1}, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter$createDetailView$1$2;-><init>(Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;Landroid/content/Context;)V" },
      { type: "opcode",    text: "    invoke-virtual {p3, p2}, Landroid/view/View;->addOnAttachStateChangeListener(Landroid/view/View$OnAttachStateChangeListener;)V" },
      { type: "opcode",    text: "    return-object p3" },
      { type: "directive", text: ".end method" },
    ],
  },
  {
    id: "misc",
    label: "Misc Methods",
    icon: "◇",
    color: "#fb923c",
    lines: [
      { type: "directive", text: ".method public final getMetricsCategory()I" },
      { type: "opcode",    text: "    const/16 p0, 0x1389    # 5001" },
      { type: "opcode",    text: "    return p0" },
      { type: "directive", text: ".end method" },
      { type: "blank",     text: "" },
      { type: "directive", text: ".method public final getSettingsIntent()Landroid/content/Intent;" },
      { type: "opcode",    text: "    new-instance p0, Landroid/content/Intent;" },
      { type: "opcode",    text: "    const-string v0, \"android.settings.DISPLAY_SETTINGS\"" },
      { type: "opcode",    text: "    invoke-direct {p0, v0}, Landroid/content/Intent;-><init>(Ljava/lang/String;)V" },
      { type: "opcode",    text: "    return-object p0" },
      { type: "directive", text: ".end method" },
      { type: "blank",     text: "" },
      { type: "directive", text: ".method public final isSwitchChecked()Z" },
      { type: "comment",   text: "    # Returns true if screen_brightness_mode=1 (auto) or display_outdoor_mode=1" },
      { type: "opcode",    text: "    iget-object p0, p0, Lcom/android/systemui/settings/brightness/BrightnessDetailAdapter;->context:Landroid/content/Context;" },
      { type: "opcode",    text: "    invoke-static {p0}, Lcom/android/systemui/util/DeviceType;->isLightSensorSupported(Landroid/content/Context;)Z" },
      { type: "opcode",    text: "    move-result v0" },
      { type: "label",     text: "    if-eqz v0, :cond_1" },
      { type: "opcode",    text: "    # ... read screen_brightness_mode ..." },
      { type: "label",     text: "    :cond_1" },
      { type: "opcode",    text: "    # ... read display_outdoor_mode ..." },
      { type: "opcode",    text: "    return v1 / v2" },
      { type: "directive", text: ".end method" },
      { type: "blank",     text: "" },
      { type: "directive", text: ".method public final setToggleState(Z)V" },
      { type: "opcode",    text: "    return-void    # no-op" },
      { type: "directive", text: ".end method" },
    ],
  },
];

const TOKEN_COLORS = {
  directive:  "#60efff",
  comment:    "#6b7280",
  opcode:     "#e2e8f0",
  label:      "#fbbf24",
  indent:     "#94a3b8",
  blank:      "transparent",
};

// ─── Tokenizer ───────────────────────────────────────────────────────────────

function tokenizeLine(text) {
  if (!text.trim()) return [{ kind: "blank", value: "" }];

  const tokens = [];
  // Highlight register refs (v0-v15, p0-p3)
  const parts = text.split(/(\b[vp]\d+\b|0x[0-9a-fA-F]+|-?\d+\b|"[^"]*"|L[\w/$]+;(?:->\w[\w$]*(?:\(.*?\)[\w/;[\]]*)?)?|:\w+)/g);
  for (const part of parts) {
    if (!part) continue;
    if (/^[vp]\d+$/.test(part))                         tokens.push({ kind: "reg",    value: part });
    else if (/^0x[0-9a-fA-F]+$/.test(part))             tokens.push({ kind: "hex",    value: part });
    else if (/^-?\d+$/.test(part))                      tokens.push({ kind: "num",    value: part });
    else if (/^"/.test(part))                            tokens.push({ kind: "str",    value: part });
    else if (/^L[\w/$]+;/.test(part))                   tokens.push({ kind: "type",   value: part });
    else if (/^:/.test(part))                            tokens.push({ kind: "lbl",    value: part });
    else                                                 tokens.push({ kind: "plain",  value: part });
  }
  return tokens;
}

const TOKEN_INLINE_COLORS = {
  reg:   "#a78bfa",
  hex:   "#34d399",
  num:   "#fb923c",
  str:   "#f472b6",
  type:  "#60efff",
  lbl:   "#fbbf24",
  plain: "#e2e8f0",
};

// ─── Components ──────────────────────────────────────────────────────────────

function GlassLine({ line, lineNumber, highlight, onClick }) {
  const tokens = useMemo(() => tokenizeLine(line.text), [line.text]);
  const isBlank = line.type === "blank";
  const isComment = line.type === "comment";

  return (
    <div
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "flex-start",
        padding: isBlank ? "2px 0" : "1px 12px 1px 0",
        borderRadius: 4,
        cursor: isBlank ? "default" : "pointer",
        background: highlight ? "rgba(96,239,255,0.07)" : "transparent",
        transition: "background 0.15s",
        fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
        fontSize: 12,
        lineHeight: "20px",
        userSelect: "text",
        minHeight: isBlank ? 8 : 20,
      }}
    >
      {/* Line number */}
      <span style={{
        minWidth: 36,
        paddingLeft: 8,
        color: highlight ? "rgba(96,239,255,0.6)" : "rgba(255,255,255,0.18)",
        textAlign: "right",
        flexShrink: 0,
        fontSize: 10,
        lineHeight: "20px",
      }}>
        {isBlank ? "" : lineNumber}
      </span>

      {/* Gutter accent */}
      <span style={{
        width: 2,
        alignSelf: "stretch",
        margin: "0 8px",
        borderRadius: 1,
        background: highlight ? "rgba(96,239,255,0.5)" : "transparent",
        flexShrink: 0,
      }} />

      {/* Token content */}
      {isBlank ? null : (
        <span style={{ color: isComment ? TOKEN_COLORS.comment : TOKEN_COLORS[line.type] ?? "#e2e8f0", flex: 1, wordBreak: "break-all" }}>
          {isComment
            ? line.text
            : tokens.map((t, i) => (
                <span key={i} style={{ color: TOKEN_INLINE_COLORS[t.kind] }}>{t.value}</span>
              ))
          }
        </span>
      )}
    </div>
  );
}

function GlassPanel({ section, isActive, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        padding: "10px 14px",
        borderRadius: 12,
        border: isActive
          ? `1px solid ${section.color}55`
          : "1px solid rgba(255,255,255,0.07)",
        background: isActive
          ? `linear-gradient(135deg, ${section.color}18, ${section.color}08)`
          : "rgba(255,255,255,0.03)",
        backdropFilter: "blur(12px)",
        cursor: "pointer",
        width: "100%",
        textAlign: "left",
        transition: "all 0.2s cubic-bezier(.4,0,.2,1)",
        boxShadow: isActive
          ? `0 0 16px ${section.color}22, inset 0 0 12px ${section.color}08`
          : "none",
      }}
    >
      <span style={{ fontSize: 16, color: section.color, flexShrink: 0 }}>{section.icon}</span>
      <span style={{
        fontSize: 12,
        fontFamily: "'JetBrains Mono', monospace",
        color: isActive ? section.color : "rgba(255,255,255,0.55)",
        fontWeight: isActive ? 600 : 400,
        letterSpacing: "0.01em",
        overflow: "hidden",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",
      }}>
        {section.label}
      </span>
      <span style={{
        marginLeft: "auto",
        fontSize: 10,
        color: "rgba(255,255,255,0.3)",
        flexShrink: 0,
      }}>
        {section.lines.filter(l => l.type !== "blank").length}L
      </span>
    </button>
  );
}

// ─── Main App ─────────────────────────────────────────────────────────────────

export default function App() {
  const [activeSection, setActiveSection] = useState(SMALI_SECTIONS[0].id);
  const [highlightedLine, setHighlightedLine] = useState(null);
  const [search, setSearch] = useState("");
  const [copied, setCopied] = useState(false);
  const codeRef = useRef(null);

  const section = useMemo(
    () => SMALI_SECTIONS.find(s => s.id === activeSection),
    [activeSection]
  );

  const filteredLines = useMemo(() => {
    if (!search.trim()) return section.lines;
    const q = search.toLowerCase();
    return section.lines.filter(l => l.text.toLowerCase().includes(q));
  }, [section, search]);

  const handleCopy = useCallback(() => {
    const text = section.lines.map(l => l.text).join("\n");
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    });
  }, [section]);

  const lineCount = section.lines.filter(l => l.type !== "blank").length;

  return (
    <div style={{
      minHeight: "100vh",
      background: "radial-gradient(ellipse 120% 80% at 60% 20%, #0d1f3c 0%, #070d1a 55%, #000 100%)",
      fontFamily: "'JetBrains Mono', monospace",
      display: "flex",
      flexDirection: "column",
      overflow: "hidden",
    }}>

      {/* ── Ambient blobs (CSS-only, no JS animation cost) ── */}
      <div aria-hidden style={{ position: "fixed", inset: 0, pointerEvents: "none", zIndex: 0, overflow: "hidden" }}>
        <div style={{
          position: "absolute", width: 600, height: 600,
          top: -200, left: -100,
          background: "radial-gradient(circle, rgba(96,239,255,0.06) 0%, transparent 70%)",
          animation: "drift1 18s ease-in-out infinite alternate",
        }} />
        <div style={{
          position: "absolute", width: 500, height: 500,
          bottom: -100, right: -80,
          background: "radial-gradient(circle, rgba(167,139,250,0.07) 0%, transparent 70%)",
          animation: "drift2 22s ease-in-out infinite alternate",
        }} />
        <style>{`
          @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;600&display=swap');
          @keyframes drift1 { from{transform:translate(0,0) scale(1)} to{transform:translate(60px,40px) scale(1.1)} }
          @keyframes drift2 { from{transform:translate(0,0) scale(1)} to{transform:translate(-50px,-30px) scale(1.08)} }
          ::-webkit-scrollbar { width: 4px; height: 4px; }
          ::-webkit-scrollbar-track { background: transparent; }
          ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.12); border-radius: 2px; }
          * { box-sizing: border-box; }
        `}</style>
      </div>

      {/* ── Header ── */}
      <header style={{
        position: "relative", zIndex: 10,
        padding: "16px 24px 14px",
        background: "rgba(255,255,255,0.03)",
        backdropFilter: "blur(20px)",
        borderBottom: "1px solid rgba(255,255,255,0.07)",
        display: "flex", alignItems: "center", gap: 16,
        flexShrink: 0,
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 10,
          background: "linear-gradient(135deg, rgba(96,239,255,0.25), rgba(167,139,250,0.15))",
          border: "1px solid rgba(96,239,255,0.3)",
          backdropFilter: "blur(8px)",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: 18, flexShrink: 0,
        }}>☀</div>
        <div>
          <div style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", letterSpacing: "0.02em" }}>
            BrightnessDetailAdapter
          </div>
          <div style={{ fontSize: 10, color: "rgba(255,255,255,0.35)", marginTop: 1 }}>
            com.android.systemui.settings.brightness · Smali
          </div>
        </div>
        <div style={{ marginLeft: "auto", display: "flex", gap: 8, alignItems: "center" }}>
          <div style={{
            padding: "3px 10px", borderRadius: 20,
            background: "rgba(52,211,153,0.12)",
            border: "1px solid rgba(52,211,153,0.25)",
            fontSize: 10, color: "#34d399", letterSpacing: "0.04em",
          }}>IMPROVED</div>
          <div style={{
            padding: "3px 10px", borderRadius: 20,
            background: "rgba(251,191,36,0.1)",
            border: "1px solid rgba(251,191,36,0.2)",
            fontSize: 10, color: "#fbbf24",
          }}>SensorPrivacy ✓</div>
        </div>
      </header>

      {/* ── Body ── */}
      <div style={{
        position: "relative", zIndex: 1,
        flex: 1, display: "flex", overflow: "hidden",
      }}>

        {/* ── Sidebar ── */}
        <aside style={{
          width: 200, flexShrink: 0,
          padding: "14px 10px",
          display: "flex", flexDirection: "column", gap: 4,
          borderRight: "1px solid rgba(255,255,255,0.06)",
          overflowY: "auto",
          background: "rgba(0,0,0,0.15)",
          backdropFilter: "blur(16px)",
        }}>
          <div style={{ fontSize: 9, color: "rgba(255,255,255,0.25)", letterSpacing: "0.1em", padding: "0 4px 8px", textTransform: "uppercase" }}>
            Sections
          </div>
          {SMALI_SECTIONS.map(s => (
            <GlassPanel
              key={s.id}
              section={s}
              isActive={activeSection === s.id}
              onClick={() => { setActiveSection(s.id); setHighlightedLine(null); setSearch(""); }}
            />
          ))}
        </aside>

        {/* ── Code panel ── */}
        <main style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>

          {/* Toolbar */}
          <div style={{
            padding: "10px 16px",
            display: "flex", alignItems: "center", gap: 10,
            borderBottom: "1px solid rgba(255,255,255,0.05)",
            background: "rgba(0,0,0,0.1)",
            backdropFilter: "blur(12px)",
            flexShrink: 0,
          }}>
            <span style={{ fontSize: 14, color: section.color }}>{section.icon}</span>
            <span style={{ fontSize: 12, color: "rgba(255,255,255,0.6)", fontWeight: 500 }}>{section.label}</span>
            <span style={{ fontSize: 10, color: "rgba(255,255,255,0.25)", marginLeft: 4 }}>
              {lineCount} lines
            </span>

            {/* Search */}
            <div style={{
              marginLeft: "auto",
              display: "flex", alignItems: "center",
              background: "rgba(255,255,255,0.05)",
              border: "1px solid rgba(255,255,255,0.09)",
              borderRadius: 8, overflow: "hidden",
              backdropFilter: "blur(8px)",
            }}>
              <span style={{ padding: "0 8px", color: "rgba(255,255,255,0.3)", fontSize: 11 }}>⌕</span>
              <input
                value={search}
                onChange={e => setSearch(e.target.value)}
                placeholder="Filter..."
                style={{
                  background: "transparent", border: "none", outline: "none",
                  color: "#e2e8f0", fontSize: 11, padding: "5px 8px 5px 0",
                  fontFamily: "'JetBrains Mono', monospace", width: 120,
                }}
              />
            </div>

            {/* Copy button */}
            <button
              onClick={handleCopy}
              style={{
                padding: "5px 12px", borderRadius: 8, border: "1px solid rgba(255,255,255,0.1)",
                background: copied ? "rgba(52,211,153,0.15)" : "rgba(255,255,255,0.05)",
                color: copied ? "#34d399" : "rgba(255,255,255,0.5)",
                cursor: "pointer", fontSize: 11,
                fontFamily: "'JetBrains Mono', monospace",
                transition: "all 0.2s",
                backdropFilter: "blur(8px)",
              }}
            >
              {copied ? "✓ copied" : "copy"}
            </button>
          </div>

          {/* Lines */}
          <div
            ref={codeRef}
            style={{
              flex: 1, overflowY: "auto", overflowX: "auto",
              padding: "10px 0 24px",
              background: "rgba(0,0,0,0.08)",
            }}
          >
            {/* Glass code container */}
            <div style={{
              margin: "0 16px",
              borderRadius: 14,
              background: "rgba(255,255,255,0.025)",
              border: "1px solid rgba(255,255,255,0.06)",
              backdropFilter: "blur(20px)",
              boxShadow: `0 4px 40px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.06), 0 0 40px ${section.color}0a`,
              overflow: "hidden",
              minWidth: 600,
            }}>
              {/* Top glass shimmer strip */}
              <div style={{
                height: 1,
                background: `linear-gradient(90deg, transparent, ${section.color}40, transparent)`,
                opacity: 0.6,
              }} />
              <div style={{ padding: "12px 0 12px" }}>
                {(search ? filteredLines : section.lines).map((line, i) => (
                  <GlassLine
                    key={i}
                    line={line}
                    lineNumber={i + 1}
                    highlight={highlightedLine === i}
                    onClick={() => setHighlightedLine(prev => prev === i ? null : i)}
                  />
                ))}
                {search && filteredLines.length === 0 && (
                  <div style={{ padding: "20px 52px", color: "rgba(255,255,255,0.2)", fontSize: 11 }}>
                    No matches for "{search}"
                  </div>
                )}
              </div>
            </div>
          </div>
        </main>
      </div>

      {/* ── Status bar ── */}
      <footer style={{
        position: "relative", zIndex: 10,
        padding: "6px 24px",
        background: "rgba(0,0,0,0.3)",
        backdropFilter: "blur(16px)",
        borderTop: "1px solid rgba(255,255,255,0.05)",
        display: "flex", alignItems: "center", gap: 20,
        flexShrink: 0,
      }}>
        {[
          ["class",    "BrightnessDetailAdapter"],
          ["lang",     "Smali / Dalvik"],
          ["sections", `${SMALI_SECTIONS.length}`],
          ["sensor",   "Privacy ✓ restored"],
        ].map(([label, val]) => (
          <div key={label} style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <span style={{ fontSize: 9, color: "rgba(255,255,255,0.2)", textTransform: "uppercase", letterSpacing: "0.08em" }}>{label}</span>
            <span style={{ fontSize: 10, color: "rgba(255,255,255,0.45)" }}>{val}</span>
          </div>
        ))}
        <div style={{ marginLeft: "auto" }}>
          <div style={{
            width: 6, height: 6, borderRadius: "50%",
            background: "#34d399",
            boxShadow: "0 0 6px #34d399",
            display: "inline-block",
          }} />
        </div>
      </footer>
    </div>
  );
}
