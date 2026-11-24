import {
  aip_make_envelope,
  aip_validate,
  aip_fanout_detail,
  aip_next_seq,
  aip_envelope_meta,
  aip_protocol_flow,
  capability_report,
  discovery_match,
  identity_aic_check,
  route_resolve,
  tool_descriptor_check,
} from "./playground.js";

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

/* ---------- 输出渲染 ---------- */

function pretty(text) {
  try {
    return JSON.stringify(JSON.parse(text), null, 2);
  } catch {
    return String(text);
  }
}

function isError(text) {
  return typeof text === "string" && text.startsWith('{"ok":false');
}

function showOut(selector, text, ok) {
  const node = $(selector);
  if (!node) return;
  node.textContent = pretty(text);
  node.classList.toggle("ok", ok === true);
  node.classList.toggle("bad", ok === false);
}

function showOk(selector, text) {
  showOut(selector, text, true);
}

function showBad(selector, text) {
  showOut(selector, text, false);
}

/* ---------- 主题 ---------- */

const THEME_KEY = "gbz185-mbt-theme";
const themeToggle = $("#theme-toggle");

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  if (themeToggle) {
    themeToggle.textContent = theme === "dark" ? "◐" : "☀";
    themeToggle.setAttribute(
      "aria-label",
      theme === "dark" ? "切换到浅色主题" : "切换到深色主题",
    );
    themeToggle.title = themeToggle.getAttribute("aria-label");
  }
}

if (themeToggle) {
  themeToggle.addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    applyTheme(next);
    try {
      localStorage.setItem(THEME_KEY, next);
    } catch {
      /* 隐私模式忽略 */
    }
  });
  applyTheme(document.documentElement.dataset.theme === "light" ? "light" : "dark");
}

/* ---------- 窄屏导航（≤960px 汉堡菜单） ---------- */

const navToggle = $("#nav-toggle");
const siteNav = $("#site-nav");

function closeNav() {
  if (!siteNav) return;
  siteNav.classList.remove("open");
  if (navToggle) {
    navToggle.setAttribute("aria-expanded", "false");
    navToggle.setAttribute("aria-label", "打开导航");
    navToggle.title = "打开导航";
  }
}

if (navToggle && siteNav) {
  navToggle.addEventListener("click", () => {
    const open = siteNav.classList.toggle("open");
    navToggle.setAttribute("aria-expanded", open ? "true" : "false");
    navToggle.setAttribute("aria-label", open ? "关闭导航" : "打开导航");
    navToggle.title = navToggle.getAttribute("aria-label");
  });
  siteNav.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", closeNav);
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeNav();
  });
  window.addEventListener("resize", () => {
    if (window.innerWidth > 960) closeNav();
  });
}

/* ---------- 演示动作 ---------- */

function runEncode() {
  const sender = $("#sender").value.trim();
  const recipient = $("#recipient").value.trim();
  const seq = Number($("#seq").value);
  const timestamp = Number($("#timestamp").value);
  const kind = $("#kind").value;
  const payload = $("#payload").value;
  if (!Number.isFinite(seq) || !Number.isFinite(timestamp)) {
    showBad("#encode-out", '{"ok":false,"error":"seq / timestamp 必须是数字"}');
    return;
  }
  if (sender.length === 0 || recipient.length === 0) {
    showBad("#encode-out", '{"ok":false,"error":"sender / recipient URN 不能为空"}');
    return;
  }
  if (!Number.isSafeInteger(seq) || seq < 1 || seq > 2147483647) {
    showBad("#encode-out", '{"ok":false,"error":"seq 必须是 1..2147483647 的整数（int32 演示范围）"}');
    return;
  }
  if (!Number.isSafeInteger(timestamp) || timestamp < 0 || timestamp > 2147483647) {
    showBad("#encode-out", '{"ok":false,"error":"timestamp 必须是 0..2147483647 的整数（int32 演示范围）"}');
    return;
  }
  const text = aip_make_envelope(sender, recipient, seq, timestamp, kind, payload);
  if (isError(text)) {
    showBad("#encode-out", text);
    return;
  }
  showOk("#encode-out", text);
  $("#json").value = text;
}

function runValidate() {
  const ok = aip_validate($("#json").value);
  if (ok) {
    showOk("#check-out", '{"ok":true,"verdict":"合法 AIP 信封（版本/协议/字段/kind 均通过）"}');
  } else {
    showBad("#check-out", '{"ok":false,"verdict":"非法信封（版本/协议/字段/kind 任一不匹配）"}');
  }
}

function runFanout() {
  const text = aip_fanout_detail($("#json").value, $("#members").value);
  (isError(text) ? showBad : showOk)("#check-out", text);
}

function runNext() {
  const cur = Number($("#curseq").value);
  if (!Number.isSafeInteger(cur) || cur < 1 || cur >= 2147483647) {
    showBad("#seq-out", '{"ok":false,"error":"seq 必须是 1..2147483646 的整数（int32 演示范围，保证 +1 不回绕）"}');
    return;
  }
  const next = aip_next_seq(cur);
  showOk("#seq-out", JSON.stringify({ ok: true, prev: cur, next, monotonic: next > cur }));
}

function runMeta() {
  const text = aip_envelope_meta($("#meta-json").value);
  (isError(text) ? showBad : showOk)("#meta-out", text);
}

function runFlow() {
  const text = aip_protocol_flow(
    $("#flow-node").value.trim(),
    $("#flow-peers").value,
    $("#flow-kind").value,
    $("#flow-payload").value,
  );
  (isError(text) ? showBad : showOk)("#flow-out", text);
}

function runCaps() {
  const text = capability_report($("#caps").value, $("#required").value);
  (isError(text) ? showBad : showOk)("#caps-out", text);
}

function runMatch() {
  const text = discovery_match(
    $("#nodes").value,
    $("#filter").value,
    $("#discoverable").checked,
  );
  (isError(text) ? showBad : showOk)("#match-out", text);
}

function runAic() {
  const text = identity_aic_check($("#aic").value.trim());
  if (isError(text)) {
    showBad("#aic-out", text);
    return;
  }
  let ok = false;
  try {
    ok = JSON.parse(text).valid === true;
  } catch {
    ok = false;
  }
  (ok ? showOk : showBad)("#aic-out", text);
}

function runRoute() {
  const text = route_resolve(
    $("#group").value.trim(),
    $("#route-members").value,
    $("#route-recipient").value.trim(),
  );
  (isError(text) ? showBad : showOk)("#route-out", text);
}

function runTool() {
  const text = tool_descriptor_check(
    $("#tool-name").value.trim(),
    $("#tool-desc").value.trim(),
    $("#tool-schema").value,
    $("#tool-binding").value,
    $("#tool-server").value.trim(),
  );
  (isError(text) ? showBad : showOk)("#tool-out", text);
}

function runHero() {
  const text = aip_protocol_flow(
    "urn:agent:walkzzz:hero",
    "urn:agent:peer-a, urn:agent:peer-b",
    "task_request",
    '{"text":"hello from MoonBit"}',
  );
  if (isError(text)) {
    $("#hero-envelope").textContent = text;
    $("#hero-status").textContent = "流程失败";
    return;
  }
  let data = null;
  try {
    data = JSON.parse(text);
  } catch {
    data = null;
  }
  if (!data) return;
  $("#hero-seq").textContent = String(data.outbox_seq);
  $("#hero-delivered").textContent = String(data.peer_watermark);
  $("#hero-peers").textContent = String((data.peers || []).length);
  $("#hero-envelope").textContent = JSON.stringify(
    {
      message_id: data.message_id,
      registered: data.is_registered,
      delivered: data.delivered,
      peers: data.peers,
    },
    null,
    2,
  );
  $("#hero-status").textContent = data.delivered
    ? "已投递（receive 校验通过）"
    : "投递失败";
}

const ACTIONS = {
  encode: runEncode,
  validate: runValidate,
  fanout: runFanout,
  next: runNext,
  meta: runMeta,
  flow: runFlow,
  caps: runCaps,
  match: runMatch,
  aic: runAic,
  route: runRoute,
  tool: runTool,
  hero: runHero,
};

$$("button[data-run]").forEach((button) => {
  button.addEventListener("click", () => {
    const action = ACTIONS[button.dataset.run];
    if (action) action();
  });
});

const PRESETS = {
  event: {
    kind: "event",
    payload: '{"event":"agent_online","at":1700000000}',
    seq: 7,
  },
  heartbeat: {
    kind: "heartbeat",
    payload: '{"interval_s":30}',
    seq: 8,
  },
};

$$("button[data-preset]").forEach((button) => {
  button.addEventListener("click", () => {
    const preset = PRESETS[button.dataset.preset];
    if (!preset) return;
    $("#kind").value = preset.kind;
    $("#payload").value = preset.payload;
    $("#seq").value = String(preset.seq);
    runEncode();
  });
});

const ENTER_ACTIONS = [
  ["#sender", "encode"],
  ["#recipient", "encode"],
  ["#seq", "encode"],
  ["#timestamp", "encode"],
  ["#payload", "encode"],
  ["#curseq", "next"],
  ["#flow-node", "flow"],
  ["#flow-peers", "flow"],
  ["#flow-payload", "flow"],
  ["#caps", "caps"],
  ["#required", "caps"],
  ["#filter", "match"],
  ["#aic", "aic"],
  ["#group", "route"],
  ["#route-recipient", "route"],
  ["#tool-name", "tool"],
  ["#tool-desc", "tool"],
  ["#tool-schema", "tool"],
  ["#tool-server", "tool"],
];

ENTER_ACTIONS.forEach(([selector, action]) => {
  const field = $(selector);
  if (!field) return;
  field.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    const button = $(`button[data-run="${action}"]`);
    if (button) button.click();
  });
});

/* ---------- 复制 ---------- */

async function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const area = document.createElement("textarea");
  area.value = text;
  area.setAttribute("readonly", "");
  area.style.position = "fixed";
  area.style.opacity = "0";
  document.body.appendChild(area);
  area.select();
  document.execCommand("copy");
  document.body.removeChild(area);
}

$$("[data-copy-target]").forEach((button) => {
  button.addEventListener("click", async () => {
    const target = document.getElementById(button.dataset.copyTarget);
    if (!target) return;
    const original = button.textContent;
    try {
      await copyText(target.textContent.trim());
      button.textContent = "已复制";
    } catch {
      button.textContent = "复制失败";
    }
    setTimeout(() => {
      button.textContent = original;
    }, 1400);
  });
});

/* ---------- 导航高亮 ---------- */

const navLinks = $$(".nav a");
const sections = navLinks
  .map((link) => document.querySelector(link.getAttribute("href")))
  .filter(Boolean);

if ("IntersectionObserver" in window && sections.length > 0) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        navLinks.forEach((link) => {
          link.classList.toggle(
            "active",
            link.getAttribute("href") === `#${entry.target.id}`,
          );
        });
      });
    },
    { rootMargin: "-45% 0px -50% 0px", threshold: 0 },
  );
  sections.forEach((section) => observer.observe(section));
}

/* ---------- 初始化 ---------- */

runHero();
runEncode();
runValidate();
runFanout();
runNext();
runMeta();
runFlow();
runCaps();
runMatch();
runAic();
runRoute();
runTool();
