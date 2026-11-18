// GB/Z 185.5 智能体发现 ADP：检索/匹配/discoverable 可见性过滤

///|
#derive(Eq, Debug)
pub(all) struct AgentNode {
  urn : String
  display_name : String
  identity : @identity.AgentIdentity
  acs : @capability.AgentCapabilitySet
  discoverable : Bool
  endpoint : String?
}

///|
pub fn AgentNode::from_frontmatter(
  urn : String,
  display_name : String,
  identity_status : @identity.IdentityStatus,
  discoverable : Bool,
  capabilities : Array[String],
  default_input_types : Array[String],
  default_output_types : Array[String],
) -> AgentNode {
  {
    urn,
    display_name,
    identity: { aic: "", identity_status, cai_ref: None, registered_at: None, },
    acs: {
      capabilities,
      default_input_types,
      default_output_types,
      constraints: [],
    },
    discoverable,
    endpoint: None,
  }
}

///|
pub fn AgentNode::to_json(self : AgentNode) -> Json {
  let endpoint_json = match self.endpoint {
    Some(e) => Json::string(e)
    None => Json::null()
  }
  {
    "urn": Json(self.urn),
    "display_name": Json(self.display_name),
    "identity": self.identity.to_json(),
    "acs": self.acs.to_json(),
    "discoverable": Json(self.discoverable),
    "endpoint": endpoint_json,
  }
}

///|
pub fn AgentNode::from_json(j : Json) -> AgentNode raise @wire.JsonWireError {
  let urn = @wire.json_string_field(j, "urn")
  let display_name = @wire.json_string_field(j, "display_name")
  let identity = @identity.AgentIdentity::from_json(
    @wire.json_object_field(j, "identity"),
  )
  let acs = @capability.AgentCapabilitySet::from_json(
    @wire.json_object_field(j, "acs"),
  )
  let discoverable = @wire.json_bool_field(j, "discoverable")
  let endpoint = @wire.json_optional_string(j, "endpoint")
  { urn, display_name, identity, acs, discoverable, endpoint, }
}

///|
/// ADP 检索与匹配：discoverable 可见性过滤 + 能力覆盖过滤（filter 为空表示不过滤）
pub fn match_nodes(
  nodes : ArrayView[AgentNode],
  filter_capabilities : ArrayView[String],
  require_discoverable~ : Bool = true,
) -> Array[AgentNode] {
  let out : Array[AgentNode] = []
  for node in nodes {
    if require_discoverable && !node.discoverable {
      continue
    }
    if filter_capabilities.length() > 0 && !node.acs.covers(filter_capabilities) {
      continue
    }
    out.push(node)
  }
  out
}

///|
pub extend AgentNode with Eq::{equal, not_equal}

///|
pub extend AgentNode with @moonbitlang/core/debug.Debug::{to_repr}
