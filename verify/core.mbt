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
  proof_ensure: res => res >= lo && res <= hi,
} {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}
