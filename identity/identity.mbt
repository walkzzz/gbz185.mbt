// GB/Z 185.2 身份管理：AIC（Agent Identity Code）编码结构/唯一标识/CAI 凭证/identity_status
// GB/Z 185.2 Identity management: AIC (Agent Identity Code) encoding structure, unique id, CAI credential, identity_status

///|
#derive(Eq, Debug)
pub(all) enum IdentityStatus {
  NoIdentity
  Active
  Locked
  Revoked
}

///|
pub fn IdentityStatus::to_wire(self : IdentityStatus) -> String {
  match self {
    NoIdentity => "none"
    Active => "active"
    Locked => "locked"
    Revoked => "revoked"
  }
}

///|
pub fn IdentityStatus::from_wire(s : String) -> IdentityStatus? {
  match s {
    "none" => Some(NoIdentity)
    "active" => Some(Active)
    "locked" => Some(Locked)
    "revoked" => Some(Revoked)
    _ => None
  }
}

///|
#derive(Eq, Debug)
pub(all) struct AgentIdentity {
  aic : String
  identity_status : IdentityStatus
  cai_ref : String?
  registered_at : Int64?
}

///|
/// AIC 身份码编码结构校验（GB/Z 185.2）：点分十进制数字段、≥2 段、每段非空。
/// 逐字符状态机实现（不依赖 split 边界行为；语义对应 verify 包可证明形式）。
/// AIC identity code structural validation (GB/Z 185.2): dot-separated decimal digit fields, >= 2 segments, each non-empty; implemented as a char-by-char state machine whose semantics mirror the provable form in the verify package.
pub fn aic_validate(oid : String) -> Bool {
  let mut segments = 1
  let mut in_seg = false
  for c in oid {
    if c == '.' {
      if !in_seg {
        return false
      }
      segments += 1
      in_seg = false
    } else if c >= '0' && c <= '9' {
      in_seg = true
    } else {
      return false
    }
  }
  in_seg && segments >= 2
}

///|
/// AIC 本栈分配段前缀（示意 OID 段，正式分配以 ACPs 注册服务为准）
/// Stack-local AIC allocation prefix (illustrative OID segment; official assignment is governed by the ACPs registry service).
pub fn aic_has_stack_prefix(oid : String) -> Bool {
  oid.has_prefix("1.2.156.185.2.")
}

///|
pub fn AgentIdentity::to_json(self : AgentIdentity) -> Json {
  let cai_ref_json = match self.cai_ref {
    Some(c) => Json::string(c)
    None => Json::null()
  }
  let registered_at_json = match self.registered_at {
    Some(t) => Json::number(t.to_double())
    None => Json::null()
  }
  {
    "aic": Json(self.aic),
    "identity_status": Json(self.identity_status.to_wire()),
    "cai_ref": cai_ref_json,
    "registered_at": registered_at_json,
  }
}

///|
pub fn AgentIdentity::from_json(
  j : Json,
) -> AgentIdentity raise @wire.JsonWireError {
  let aic = @wire.json_string_field(j, "aic")
  let status_wire = @wire.json_string_field(j, "identity_status")
  guard IdentityStatus::from_wire(status_wire) is Some(status) else {
    raise BadValue("identity_status", status_wire)
  }
  let cai_ref = @wire.json_optional_string(j, "cai_ref")
  let registered_at = @wire.json_optional_int64(j, "registered_at")
  { aic, identity_status: status, cai_ref, registered_at, }
}

///|
pub extend IdentityStatus with Eq::{equal, not_equal}

///|
pub extend IdentityStatus with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AgentIdentity with Eq::{equal, not_equal}

///|
pub extend AgentIdentity with @moonbitlang/core/debug.Debug::{to_repr}
