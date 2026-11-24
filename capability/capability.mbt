// GB/Z 185.4 智能体描述 ACS（Agent Capability Statement）：能力元数据/接口/输入输出/约束
// GB/Z 185.4 Agent description ACS (Agent Capability Statement): capability metadata, interfaces, input/output types, constraints

///|
#derive(Eq, Debug)
pub(all) struct AgentCapabilitySet {
  capabilities : Array[String]
  default_input_types : Array[String]
  default_output_types : Array[String]
  constraints : Array[String]
}

///|
pub fn AgentCapabilitySet::empty() -> AgentCapabilitySet {
  {
    capabilities: [],
    default_input_types: [],
    default_output_types: [],
    constraints: [],
  }
}

///|
pub fn AgentCapabilitySet::to_json(self : AgentCapabilitySet) -> Json {
  {
    "capabilities": Json(self.capabilities),
    "default_input_types": Json(self.default_input_types),
    "default_output_types": Json(self.default_output_types),
    "constraints": Json(self.constraints),
  }
}

///|
pub fn AgentCapabilitySet::from_json(
  j : Json,
) -> AgentCapabilitySet raise @wire.JsonWireError {
  {
    capabilities: @wire.json_string_array_opt(j, "capabilities"),
    default_input_types: @wire.json_string_array_opt(j, "default_input_types"),
    default_output_types: @wire.json_string_array_opt(j, "default_output_types"),
    constraints: @wire.json_string_array_opt(j, "constraints"),
  }
}

///|
/// 能力条目数（诊断/展示用）
/// Number of capability entries (for diagnostics and display).
pub fn AgentCapabilitySet::count(self : AgentCapabilitySet) -> Int32 {
  self.capabilities.length()
}

///|
fn has_capability(caps : Array[String], req : String) -> Bool {
  for cap in caps {
    if cap == req {
      return true
    }
  }
  false
}

///|
/// ACS 匹配原语（GB/Z 185.5 发现匹配的底层）：能力集是否覆盖全部所需能力
/// ACS matching primitive (underlying the GB/Z 185.5 discovery matching): whether the capability set covers all required capabilities.
pub fn AgentCapabilitySet::covers(
  self : AgentCapabilitySet,
  required : ArrayView[String],
) -> Bool {
  for req in required {
    if !has_capability(self.capabilities, req) {
      return false
    }
  }
  true
}

///|
/// 覆盖诊断：返回 required 中尚未具备的能力（保持入参顺序并去重；空数组即完全覆盖）
/// Coverage diagnostic: capabilities from `required` that are not present (input order preserved, duplicates removed; empty means fully covered).
pub fn AgentCapabilitySet::missing(
  self : AgentCapabilitySet,
  required : ArrayView[String],
) -> Array[String] {
  let out : Array[String] = []
  for req in required {
    if out.contains(req) {
      continue
    }
    if !has_capability(self.capabilities, req) {
      out.push(req)
    }
  }
  out
}

///|
/// 任一匹配：required 中至少有一项能力被具备（空需求返回 false）
/// Any-match: at least one capability in `required` is present (an empty requirement returns false).
pub fn AgentCapabilitySet::covers_any(
  self : AgentCapabilitySet,
  required : ArrayView[String],
) -> Bool {
  for req in required {
    if has_capability(self.capabilities, req) {
      return true
    }
  }
  false
}

///|
pub extend AgentCapabilitySet with Eq::{equal, not_equal}

///|
pub extend AgentCapabilitySet with @moonbitlang/core/debug.Debug::{to_repr}
