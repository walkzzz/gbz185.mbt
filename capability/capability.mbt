// GB/Z 185.4 智能体描述 ACS（Agent Capability Statement）：能力元数据/接口/输入输出/约束

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
/// ACS 匹配原语（GB/Z 185.5 发现匹配的底层）：能力集是否覆盖全部所需能力
pub fn AgentCapabilitySet::covers(
  self : AgentCapabilitySet,
  required : ArrayView[String],
) -> Bool {
  for req in required {
    let mut found = false
    for cap in self.capabilities {
      if cap == req {
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
pub extend AgentCapabilitySet with Eq::{equal, not_equal}

///|
pub extend AgentCapabilitySet with @moonbitlang/core/debug.Debug::{to_repr}
