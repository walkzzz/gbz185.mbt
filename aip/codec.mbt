// GB/Z 185.6 AIP wire 编解码（信封与四原语消息；模型编解码已归 identity/capability/discovery 各包）
// GB/Z 185.6 AIP wire codec (envelope and four-primitive messages; model codecs live in the identity/capability/discovery packages)

///|
pub fn AipEnvelope::to_json(self : AipEnvelope) -> Json {
  {
    "envelope_version": Json(self.envelope_version),
    "protocol": Json(protocol_name()),
    "sender_urn": Json(self.sender_urn),
    "recipient_urn": Json(self.recipient_urn),
    "seq": Json::number(self.seq.to_double()),
    "timestamp": Json::number(self.timestamp.to_double()),
    "kind": Json(self.kind.to_wire()),
    "payload": self.payload,
  }
}

///|
pub fn AipEnvelope::from_json(
  j : Json,
) -> AipEnvelope raise @wire.JsonWireError {
  let ver = @wire.json_string_field(j, "envelope_version")
  guard ver == envelope_version() else {
    raise BadValue("envelope_version", ver)
  }
  let p = @wire.json_string_field(j, "protocol")
  guard p == protocol_name() else { raise BadValue("protocol", p) }
  let sender = @wire.json_string_field(j, "sender_urn")
  let recipient = @wire.json_string_field(j, "recipient_urn")
  let seq = @wire.json_int64_field(j, "seq")
  let ts = @wire.json_int64_field(j, "timestamp")
  let kind_wire = @wire.json_string_field(j, "kind")
  guard MessageKind::from_wire(kind_wire) is Some(kind) else {
    raise BadValue("kind", kind_wire)
  }
  let payload = @wire.json_object_field(j, "payload")
  {
    envelope_version: ver,
    sender_urn: sender,
    recipient_urn: recipient,
    seq,
    timestamp: ts,
    kind,
    payload,
  }
}

///|
pub fn DiscoverRequest::to_json(self : DiscoverRequest) -> Json {
  {
    "requester_urn": Json(self.requester_urn),
    "filter_capabilities": Json(self.filter_capabilities),
  }
}

///|
pub fn DiscoverRequest::from_json(
  j : Json,
) -> DiscoverRequest raise @wire.JsonWireError {
  let requester_urn = @wire.json_string_field(j, "requester_urn")
  {
    requester_urn,
    filter_capabilities: @wire.json_string_array_opt(j, "filter_capabilities"),
  }
}

///|
pub fn DiscoverResponse::to_json(self : DiscoverResponse) -> Json {
  let items : Array[Json] = []
  for node in self.nodes {
    items.push(node.to_json())
  }
  { "nodes": Json::array(items) }
}

///|
pub fn DiscoverResponse::from_json(
  j : Json,
) -> DiscoverResponse raise @wire.JsonWireError {
  let nodes_j = @wire.json_object_field(j, "nodes")
  let nodes : Array[@discovery.AgentNode] = []
  match nodes_j {
    Array(items) =>
      for item in items {
        nodes.push(@discovery.AgentNode::from_json(item))
      }
    _ => raise BadType("nodes", "array")
  }
  { nodes, }
}

///|
pub fn RegisterRequest::to_json(self : RegisterRequest) -> Json {
  { "node": self.node.to_json() }
}

///|
pub fn RegisterRequest::from_json(
  j : Json,
) -> RegisterRequest raise @wire.JsonWireError {
  let node_j = @wire.json_object_field(j, "node")
  { node: @discovery.AgentNode::from_json(node_j), }
}

///|
pub fn RegisterResponse::to_json(self : RegisterResponse) -> Json {
  let aic_json = match self.aic {
    Some(a) => Json::string(a)
    None => Json::null()
  }
  let reason_json = match self.reason {
    Some(r) => Json::string(r)
    None => Json::null()
  }
  { "accepted": Json(self.accepted), "aic": aic_json, "reason": reason_json }
}

///|
pub fn RegisterResponse::from_json(
  j : Json,
) -> RegisterResponse raise @wire.JsonWireError {
  let accepted = @wire.json_bool_field(j, "accepted")
  let aic = @wire.json_optional_string(j, "aic")
  let reason = @wire.json_optional_string(j, "reason")
  { accepted, aic, reason, }
}

///|
pub fn CapabilityRequest::to_json(self : CapabilityRequest) -> Json {
  {
    "requester_urn": Json(self.requester_urn),
    "target_urn": Json(self.target_urn),
  }
}

///|
pub fn CapabilityRequest::from_json(
  j : Json,
) -> CapabilityRequest raise @wire.JsonWireError {
  let requester_urn = @wire.json_string_field(j, "requester_urn")
  let target_urn = @wire.json_string_field(j, "target_urn")
  { requester_urn, target_urn, }
}
