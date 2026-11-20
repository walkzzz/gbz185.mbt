import { aip_make_envelope, aip_validate, aip_fanout_count, aip_next_seq } from "./playground.js";

const $ = (sel) => document.querySelector(sel);
const setOut = (id, text) => {
  $(id).textContent = text;
};

function encode() {
  const sender = $("#sender").value.trim();
  const recipient = $("#recipient").value.trim();
  const seq = Number($("#seq").value);
  const timestamp = Number($("#timestamp").value);
  const kind = $("#kind").value;
  const payload = $("#payload").value;
  if (!Number.isFinite(seq) || !Number.isFinite(timestamp)) {
    setOut("#encode-out", "错误：seq / timestamp 必须是数字");
    return;
  }
  try {
    const json = aip_make_envelope(sender, recipient, seq | 0, timestamp | 0, kind, payload);
    setOut("#encode-out", json);
    $("#json").value = json;
  } catch (e) {
    setOut("#encode-out", "调用失败：" + e.message);
  }
}

function validate() {
  const json = $("#json").value;
  try {
    const ok = aip_validate(json);
    setOut("#check-out", ok ? "✅ 合法 AIP 信封（版本/协议/字段/kind 均通过）" : "❌ 非法信封（版本/协议/字段/kind 任一不匹配）");
  } catch (e) {
    setOut("#check-out", "调用失败：" + e.message);
  }
}

function fanout() {
  try {
    const n = aip_fanout_count($("#json").value, $("#members").value);
    setOut("#check-out", n >= 0 ? `✅ 扇出 ${n} 个成员信封（每个 recipient_urn 替换为成员 URN）` : "❌ 无法扇出：信封非法");
  } catch (e) {
    setOut("#check-out", "调用失败：" + e.message);
  }
}

function nextSeq() {
  const cur = Number($("#curseq").value);
  if (!Number.isFinite(cur)) {
    setOut("#seq-out", "错误：seq 必须是数字");
    return;
  }
  const next = aip_next_seq(cur | 0);
  setOut("#seq-out", `seq ${cur} → ${next}（单调 +1，防重放）`);
}

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

document.querySelectorAll("button[data-run]").forEach((b) => {
  b.addEventListener("click", () => {
    const kind = b.dataset.run;
    if (kind === "encode") encode();
    else if (kind === "validate") validate();
    else if (kind === "fanout") fanout();
    else if (kind === "next") nextSeq();
  });
});
document.querySelectorAll("button[data-preset]").forEach((b) => {
  b.addEventListener("click", () => {
    const p = PRESETS[b.dataset.preset];
    $("#kind").value = p.kind;
    $("#payload").value = p.payload;
    $("#seq").value = String(p.seq);
    encode();
  });
});

setOut("#encode-out", "已加载（JavaScript / MoonBit 同源实现）：点击「编码」。");
setOut("#check-out", "等待操作…");
setOut("#seq-out", "等待推进…");