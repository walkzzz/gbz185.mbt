/// 形式化验证（GB/Z 185 协议栈，moon proof / Why3 + SMT）。
///
/// 证明义务由 SMT 机器可查（"已证明 = 已使用"：clamp_i64 被 registry 包真实调用）。
/// SMT solver（z3/cvc5/alt-ergo）安装后运行 `moon prove` 验证；
/// 未安装时 `moon check` 仍可通过（证明义务生成，验证延后）。
/// Formal verification for the GB/Z 185 stack (moon proof / Why3 + SMT): proof obligations are machine-checkable ("proven = used": clamp_i64 is really called by the registry package); run `moon prove` once a solver (z3/cvc5/alt-ergo) is installed, while `moon check` still passes without one (obligations generated, verification deferred).

///|
/// 整数钳制：把 v 限制进 [lo, hi]。
///
/// 证明义务：前置 lo <= hi 时，返回值满足 lo <= res <= hi。
/// 用于 ATR 注册序号（AIC 分配段）的硬边界防护。
/// Integer clamping: constrain v into [lo, hi]; proof obligation lo <= hi |- lo <= res <= hi; hard-bound guard for the ATR registration sequence (AIC allocation segment).
pub fn clamp_i64(
  v : Int64,
  lo : Int64,
  hi : Int64,
) -> Int64 where {
  proof_require: lo <= hi,
  proof_ensure: res => {
    (res == v && v >= lo && v <= hi) ||
    (res == lo && v < lo) ||
    (res == hi && v > hi)
  },
} {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// AIP 信封序号推进（GB/Z 185.6 防重放契约的数学基础）。
///
/// 证明义务：前置 prev >= 0（序号从 0 起单调分配）时，返回值严格大于 prev。
/// 被 aip 包 dispatch 真实调用——每次分发产生的新序号必然大于历史序号，
/// 「单调递增」性质由 Z3 证明而非仅靠测试抽样。
/// AIP envelope sequence advance: proof obligation prev >= 0 |- res > prev (strictly monotonic, the mathematical basis of anti-replay); really called by the aip package dispatch.
pub fn next_seq(
  prev : Int64,
) -> Int64 where {
  proof_require: prev >= 0,
  proof_ensure: res => res == prev + 1 && res > prev,
} {
  prev + 1
}

///|
/// AIP 防重放准入裁决纯函数（GB/Z 185.6）：incoming 相对 last 的准入判定。
///
/// 证明义务：结果**恒等于**「incoming > last」——防重放规格的机器可查形式，
/// 判定逻辑与规格文档逐字对应（规格条款：仅严格递增的序号被接受）。
/// 被 aip 包 receive 真实调用——裁决行为由 Z3 证明与规格一致。
/// AIP anti-replay admission gate: proof obligation res == (incoming > last) —
/// the replay-specification clause machine-checked; really called by the aip package receive.
pub fn inbox_advance(
  last : Int64,
  incoming : Int64,
) -> Bool where {
  proof_require: last >= 0,
  proof_ensure: res => res == (incoming > last),
} {
  incoming > last
}

///|
/// 第一档 1：钳制不破坏防重放——clamp_i64 与 next_seq 语义的组合链。
///
/// 证明义务：前置 last < lo <= hi 且 v > last 时，clamp_i64(v, lo, hi) > last。
/// 组合性质（Z3 直接可证）：无论 v 落在哪个分支（低于 lo / 高于 hi / 区间内），
/// 钳制结果都保持对 last 的严格大于——ATR 注册段的边界防护不会倒退序号。
/// Tier-1 #1: clamping preserves anti-replay — for last < lo <= hi and v > last,
/// the clamped result stays strictly above last (no branch regresses the sequence).
pub fn clamp_keeps_above(
  last : Int64,
  v : Int64,
  lo : Int64,
  hi : Int64,
) -> Bool where {
  proof_require: last < lo,
  proof_require: lo <= hi,
  proof_require: v > last,
  proof_ensure: res => res == true,
} {
  clamp_i64(v, lo, hi) > last
}

///|
/// 第一档 2：防重放传递链——三次投递的序号链上准入判定保持。
///
/// 证明义务：mid > last 且 incoming > mid 时，inbox_advance(last, incoming) 恒真。
/// 与 next_seq/inbox_advance 构成防重放的三级证明链（单步推进 → 链式传递）。
/// Tier-1 #2: replay chain transitivity — admission holds across a three-hop
/// strictly increasing delivery chain.
pub fn replay_chain(
  last : Int64,
  mid : Int64,
  incoming : Int64,
) -> Bool where {
  proof_require: last >= 0,
  proof_require: mid > last,
  proof_require: incoming > mid,
  proof_ensure: res => res == true,
} {
  inbox_advance(last, incoming)
}

///|
/// 第一档 3：mock 信封生成器的序号推进核（GB/Z 185.6 mock 数据面）。
///
/// gen_seq(base, i) = base + i + 1：generate_dispatch_envelopes 的序号路径核模型，
/// 证明义务：前置 base >= 0 且 i >= 0 时推进核恒大于 base（属性测试的元性质）。
/// Tier-1 #3: generator sequence advance — gen_seq(base, i) = base + i + 1 always
/// advances past base for the mock-envelope generator path.
pub fn gen_seq(
  base : Int64,
  i : Int64,
) -> Int64 where {
  proof_require: base >= 0,
  proof_require: i >= 0,
  proof_ensure: res => res == base + i + 1,
} {
  base + i + 1
}

///|
pub fn gen_seq_advances(
  base : Int64,
  i : Int64,
) -> Bool where {
  proof_require: base >= 0,
  proof_require: i >= 0,
  proof_ensure: res => res == true,
} {
  gen_seq(base, i) > base
}

///|
/// 第一档 4：生成器严格递增——任意相邻两次生成序号严格上升。
///
/// 证明义务：gen_seq(base, i) < gen_seq(base, i + 1)——mock 数据自身满足防重放契约，
/// 属性测试用例不会因生成器缺陷产生假阳性/假阴性。
/// Tier-1 #4: generator strict monotonicity — consecutive generated sequences
/// strictly increase, so property tests never inherit generator flaws.
pub fn gen_seq_strict(
  base : Int64,
  i : Int64,
) -> Bool where {
  proof_require: base >= 0,
  proof_require: i >= 0,
  proof_ensure: res => res == true,
} {
  gen_seq(base, i) < gen_seq(base, i + 1)
}

///|
/// 第二档 1：注册激活语义的核模型（GB/Z 185.3 ATR 状态机）。
///
/// 状态编码：0 = 未注册（STATE_PENDING），1 = 已注册激活（STATE_ACTIVE）——
/// aip 包 dispatch 的身份门槛「requires active identity」的机器可查形式；
/// 真实实现行为由互连演示与测试对齐本核模型（model-based oracle）。
/// Tier-2 #1: registration activation core model — pending(0)/active(1) states,
/// matching the aip dispatch identity gate; real behavior is aligned to this
/// oracle by the interconnect demo and tests.
pub const STATE_PENDING : Int32 = 0

///|
pub const STATE_ACTIVE : Int32 = 1

///|
pub fn activation_after2(
  state : Int32,
  accepted : Bool,
) -> Int32 where {
  proof_ensure: res => {
    (accepted && res == STATE_ACTIVE) || (!accepted && res == state)
  },
} {
  if accepted {
    STATE_ACTIVE
  } else {
    state
  }
}

///|
pub fn dispatch_allowed(
  state : Int32,
) -> Bool where {
  proof_ensure: res => res == (state == STATE_ACTIVE),
} {
  state == STATE_ACTIVE
}

///|
pub fn register_accepts_enables_dispatch() -> Bool where {
  proof_ensure: res => res == true,
} {
  dispatch_allowed(activation_after2(STATE_PENDING, true))
}

///|
pub fn unregistered_dispatch_denied() -> Bool where {
  proof_ensure: res => res == false,
} {
  dispatch_allowed(STATE_PENDING)
}

///|
/// 第二档 2：inbox 推进的单调不变量（GB/Z 185.6 接收面）。
///
/// 证明义务：admitted 判定与防重放规格一致时，inbox 更新后 last_seen 单调不减
/// （接受则严格推进到 incoming，拒绝则保持 last）——接收面状态永不清零、永不回退。
/// Tier-2 #2: inbox monotonic invariant — after a spec-conformant admission the
/// inbox watermark never decreases (strict advance on accept, hold on reject).
pub fn inbox_update(
  last : Int64,
  incoming : Int64,
  admitted : Bool,
) -> Int64 where {
  proof_require: last >= 0,
  proof_ensure: res => {
    (admitted && res == incoming) || (!admitted && res == last)
  },
} {
  if admitted {
    incoming
  } else {
    last
  }
}

///|
pub fn inbox_monotonic(
  last : Int64,
  incoming : Int64,
  admitted : Bool,
) -> Bool where {
  proof_require: last >= 0,
  proof_require: admitted == (incoming > last),
  proof_ensure: res => res == true,
} {
  inbox_update(last, incoming, admitted) >= last
}

///|
/// 第二档 3：跨状态机组合性质——发送方新序号必然被合法接收方接受。
///
/// 证明义务：发送方从 prev 推进（next_seq），接收方对同一发送者的 watermark
/// 不超过 prev 时，inbox_advance(peer_last, next_seq(prev)) 恒真——
/// 防重放契约在「发送推进 × 接收准入」两侧组合下闭合（互不干扰的序号空间）。
/// Tier-2 #3: cross-machine composition — a freshly advanced sender sequence is
/// always admitted by a peer whose per-sender watermark does not exceed prev.
pub fn dispatch_seq_admitted_by_peer(
  prev : Int64,
  peer_last_for_sender : Int64,
) -> Bool where {
  proof_require: prev >= 0,
  proof_require: peer_last_for_sender >= 0,
  proof_require: peer_last_for_sender <= prev,
  proof_ensure: res => res == true,
} {
  inbox_advance(peer_last_for_sender, next_seq(prev))
}

///|
/// 第二档 4：ATR 容量防护（GB/Z 185.3 注册面）。
///
/// 证明义务：count < max 时注册推进后仍满足 after_register(count) <= max——
/// 容量计数在合法注册下永不过冲（RegistryFull 拒绝路径的存在性由实现保证）。
/// Tier-2 #4: registry capacity guard — one registration inside capacity keeps
/// the count within max, so the counter never overshoots on legal registrations.
pub fn after_register(
  count : Int32,
) -> Int32 where {
  proof_ensure: res => res == count + 1,
} {
  count + 1
}

///|
pub fn register_within_capacity(
  count : Int32,
  max : Int32,
) -> Bool where {
  proof_require: count < max,
  proof_ensure: res => res == true,
} {
  after_register(count) <= max
}

///|
/// 第三档 1：JS 精度安全域（wire 数值字段的 Int64→Json::number 路径）。
///
/// JS_SAFE_BOUND = 2^53：wire 数字字段（信封序号等）经 double 编解码的精确边界——
/// 证明义务：安全域内的分配器推进（next_seq）仍落在安全域内。
/// 与 wire 包「Int64 数字字段显式 Json::number(to_double)」的设计决策直接对应。
/// Tier-3 #1: JS precision safe domain — advancing an allocator inside 2^53
/// stays inside; the machine-checked form of the wire Int64→Json::number decision.
pub const JS_SAFE_BOUND : Int64 = 9007199254740992L

///|
pub fn in_js_safe_domain(
  v : Int64,
) -> Bool where {
  proof_ensure: res => res == (v > -JS_SAFE_BOUND && v < JS_SAFE_BOUND),
} {
  v > -JS_SAFE_BOUND && v < JS_SAFE_BOUND
}

///|
pub fn safe_domain_no_overflow(
  allocated : Int64,
) -> Bool where {
  proof_require: allocated >= 0,
  proof_require: allocated < JS_SAFE_BOUND - 1,
  proof_ensure: res => res == true,
} {
  in_js_safe_domain(next_seq(allocated))
}

///|
/// 第三档 2：AIC 分配段边界内钳制恒等（GB/Z 185.2/185.3 组合）。
///
/// 证明义务：prev 在段 [0, seg_hi] 内推进时，clamp_i64(next_seq(prev), 0, seg_hi)
/// 恒等于 next_seq(prev)——分配器在合法段内推进**不会触发钳制**（永不越界）；
/// 一旦越界钳制兜底（clamp_keeps_above 保证不回退防重放）。
/// Tier-3 #2: in-range AIC segment allocation makes the clamp a no-op — the
/// allocator never crosses the segment boundary while legal; if it ever did,
/// clamp_keeps_above guarantees no anti-replay regression.
pub fn aic_alloc_guard(
  prev : Int64,
  seg_hi : Int64,
) -> Bool where {
  proof_require: prev >= 0,
  proof_require: prev < seg_hi,
  proof_require: seg_hi < JS_SAFE_BOUND,
  proof_ensure: res => res == true,
} {
  clamp_i64(next_seq(prev), 0, seg_hi) == next_seq(prev)
}
