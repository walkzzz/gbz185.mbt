///|
/// GB/Z 185 AIP 浏览器演示导出层（JS / WasmGC 目标）。
/// AIP browser-demo exports. Non-raising signatures: errors fold into
/// `{"ok":false,...}` / false / -1 so the JS side needs no exception mapping.

///|
fn error_json(msg : String) -> String {
  let j : @json.Json = { "ok": @json.Json(false), "error": @json.Json(msg) }
  j.stringify()
}

///|
/// 逗号分隔清单 → 去空白/去空项数组（成员、能力、对端通用）
/// Comma-separated list -> trimmed non-empty items (members, capabilities, peers).
fn split_csv(csv : String) -> Array[String] {
  let out : Array[String] = []
  for part in csv.split(",") {
    let s = part.trim(chars=" ").to_owned()
    if s.length() > 0 {
      out.push(s)
    }
  }
  out
}

///|
/// 字符串数组 → JSON 数组
fn json_strings(items : Array[String]) -> @json.Json {
  let out : Array[@json.Json] = []
  for s in items {
    out.push(@json.Json(s))
  }
  @json.Json::array(out)
}

///|
/// 构造规范化 AIP 信封 JSON（GB/Z 185.6）
#export_name("aip_make_envelope")
pub fn aip_make_envelope(
  sender : String,
  recipient : String,
  seq : Int32,
  timestamp : Int32,
  kind : String,
  payload_json : String,
) -> String {
  if sender.trim(chars=" ").length() == 0 {
    return error_json("sender URN required")
  }
  if recipient.trim(chars=" ").length() == 0 {
    return error_json("recipient URN required")
  }
  if seq <= 0 {
    return error_json("seq must be positive (1..2147483647)")
  }
  if timestamp < 0 {
    return error_json("timestamp must be non-negative")
  }
  let kind = match @aip.MessageKind::from_wire(kind) {
    Some(k) => k
    None => return error_json("unknown kind: \{kind}")
  }
  let payload = @json.parse(payload_json) catch {
    _ => return error_json("invalid payload JSON")
  }
  let env : @aip.AipEnvelope = {
    envelope_version: @aip.envelope_version(),
    sender_urn: sender,
    recipient_urn: recipient,
    seq: seq.to_int64(),
    timestamp: timestamp.to_int64(),
    kind,
    payload,
  }
  env.to_json().stringify()
}

///|
/// 校验 AIP 信封 JSON（版本/协议/字段/消息类型 + 取值语义）
/// Validate an AIP envelope: structure (version/protocol/fields/kind) plus value semantics
/// (non-empty sender/recipient, seq > 0, timestamp >= 0).
#export_name("aip_validate")
pub fn aip_validate(json : String) -> Bool {
  try {
    let parsed = @json.parse(json)
    let env = @aip.AipEnvelope::from_json(parsed)
    env.sender_urn.trim(chars=" ").length() > 0 &&
    env.recipient_urn.trim(chars=" ").length() > 0 &&
    env.seq > 0L &&
    env.timestamp >= 0L
  } catch {
    _ => false
  }
}

///|
/// 群组扇出：返回展开后的信封数（成员以逗号分隔）。
/// 返回值：>=0 扇出数；-1 信封非法；-2 无成员（与路由卡「空群组拒绝」口径一致）。
#export_name("aip_fanout_count")
pub fn aip_fanout_count(json : String, members_csv : String) -> Int32 {
  try {
    let parsed = @json.parse(json)
    let env = @aip.AipEnvelope::from_json(parsed)
    let members = split_csv(members_csv)
    if members.length() == 0 {
      return -2
    }
    @aip.fanout(env, members[:]).length()
  } catch {
    _ => -1
  }
}

///|
/// 序号推进（verify.next_seq 的运行时投影）
#export_name("aip_next_seq")
pub fn aip_next_seq(seq : Int32) -> Int32 {
  @verify.next_seq(seq.to_int64()).to_int()
}

///|
/// 信封元数据投影：解析信封并返回字段 + 消息标识（AipEnvelope::message_id 单源）
#export_name("aip_envelope_meta")
pub fn aip_envelope_meta(json : String) -> String {
  let parsed = @json.parse(json) catch {
    _ => return error_json("invalid JSON")
  }
  let env = @aip.AipEnvelope::from_json(parsed) catch {
    _ => return error_json("invalid AIP envelope")
  }
  let j : @json.Json = {
    "ok": @json.Json(true),
    "sender_urn": @json.Json(env.sender_urn),
    "recipient_urn": @json.Json(env.recipient_urn),
    "seq": @json.Json::number(env.seq.to_double()),
    "timestamp": @json.Json::number(env.timestamp.to_double()),
    "kind": @json.Json(env.kind.to_wire()),
    "message_id": @json.Json(env.message_id()),
  }
  j.stringify()
}

///|
/// AIP 完整流程演示（185.3 注册 → 185.5 发现 → 185.6 分发/接收）：
/// 返回注册状态、对端清单、发送序号、投递结果与对端水位。
#export_name("aip_protocol_flow")
pub fn aip_protocol_flow(
  node_urn : String,
  peers_csv : String,
  kind : String,
  payload_json : String,
) -> String {
  let kind = match @aip.MessageKind::from_wire(kind) {
    Some(k) => k
    None => return error_json("unknown kind: \{kind}")
  }
  let payload = @json.parse(payload_json) catch {
    _ => return error_json("invalid payload JSON")
  }
  let peer_urns = split_csv(peers_csv)
  if node_urn.trim(chars=" ").length() == 0 {
    return error_json("node URN required")
  }
  if peer_urns.length() == 0 {
    return error_json("at least one peer URN required")
  }
  let me = @discovery.AgentNode::from_frontmatter(
    node_urn,
    node_urn,
    @identity.NoIdentity,
    true,
    [],
    [],
    [],
  )
  let proto = @aip.AipProtocol::new(me)
  let accepted = try {
    @aip.AipProtocol::handle_register_response(proto, {
      accepted: true,
      aic: Some("1.2.156.185.2.1.1"),
      reason: None,
    })
    true
  } catch {
    _ => false
  }
  if !accepted {
    return error_json("registration rejected")
  }
  let peers : Array[@discovery.AgentNode] = []
  for urn in peer_urns {
    peers.push(
      @discovery.AgentNode::from_frontmatter(
        urn,
        urn,
        @identity.Active,
        true,
        [],
        [],
        [],
      ),
    )
  }
  let _ = @aip.AipProtocol::handle_discover_response(proto, { nodes: peers, })
  let target = peers[0]
  let env = @aip.AipProtocol::dispatch(proto, kind, target.urn, payload) catch {
    _ => return error_json("dispatch failed (unknown recipient)")
  }
  let peer_proto = @aip.AipProtocol::new(target)
  let delivered = try {
    let msg = @aip.AipProtocol::receive(peer_proto, env)
    msg.message_id == env.message_id()
  } catch {
    _ => false
  }
  let j : @json.Json = {
    "ok": @json.Json(true),
    "is_registered": @json.Json(@aip.AipProtocol::is_registered(proto)),
    "peers": json_strings(@aip.AipProtocol::peer_urns(proto)),
    "outbox_seq": @json.Json::number(
      @aip.AipProtocol::outbox_seq(proto).to_double(),
    ),
    "envelope": @json.Json::number(env.seq.to_double()),
    "message_id": @json.Json(env.message_id()),
    "delivered": @json.Json(delivered),
    "peer_watermark": @json.Json::number(
      @aip.AipProtocol::inbox_watermark(peer_proto, node_urn).to_double(),
    ),
  }
  j.stringify()
}

///|
/// ACS 能力报告（GB/Z 185.4）：覆盖判定 + 能力条目数 + 缺失清单
#export_name("capability_report")
pub fn capability_report(caps_csv : String, required_csv : String) -> String {
  let acs : @capability.AgentCapabilitySet = {
    capabilities: split_csv(caps_csv),
    default_input_types: [],
    default_output_types: [],
    constraints: [],
  }
  let required = split_csv(required_csv)
  let j : @json.Json = {
    "ok": @json.Json(true),
    "covered": @json.Json(acs.covers(required[:])),
    "count": @json.Json::number(acs.count().to_double()),
    "missing": json_strings(acs.missing(required[:])),
  }
  j.stringify()
}

///|
/// ADP 发现匹配（GB/Z 185.5）：nodes_json 为 AgentNode 数组，输出匹配数量与 URN 清单
#export_name("discovery_match")
pub fn discovery_match(
  nodes_json : String,
  required_csv : String,
  require_discoverable : Bool,
) -> String {
  let parsed = @json.parse(nodes_json) catch {
    _ => return error_json("invalid nodes JSON")
  }
  let nodes : Array[@discovery.AgentNode] = []
  match parsed {
    @json.Json::Array(items) =>
      for item in items {
        let node = @discovery.AgentNode::from_json(item) catch {
          _ => return error_json("invalid node JSON")
        }
        nodes.push(node)
      }
    _ => return error_json("nodes must be a JSON array")
  }
  let matched = @discovery.match_nodes(
    nodes[:],
    split_csv(required_csv)[:],
    require_discoverable~,
  )
  let urns : Array[String] = []
  let names : Array[String] = []
  for n in matched {
    urns.push(n.urn)
    names.push(n.display_name)
  }
  let j : @json.Json = {
    "ok": @json.Json(true),
    "count": @json.Json::number(matched.length().to_double()),
    "urns": json_strings(urns),
    "names": json_strings(names),
  }
  j.stringify()
}

///|
/// AIC 身份码校验（GB/Z 185.2）：结构合法性 + 本栈段前缀
#export_name("identity_aic_check")
pub fn identity_aic_check(aic : String) -> String {
  let j : @json.Json = {
    "ok": @json.Json(true),
    "valid": @json.Json(@identity.aic_validate(aic)),
    "stack_prefix": @json.Json(@identity.aic_has_stack_prefix(aic)),
  }
  j.stringify()
}

///|
/// 路由解析演示（GB/Z 185.6）：建群组 + 成员 → resolve(recipient) 的决策投影
#export_name("route_resolve")
pub fn route_resolve(
  group_urn : String,
  members_csv : String,
  recipient : String,
) -> String {
  let table = @aip.RouteTable::new()
  table.add_group(group_urn)
  for m in split_csv(members_csv) {
    table.join(group_urn, m)
  }
  let decision : @json.Json = match table.resolve(recipient) {
    @aip.RouteDecision::Direct(urn) =>
      {
        "ok": @json.Json(true),
        "decision": @json.Json("direct"),
        "target": @json.Json(urn),
      }
    @aip.RouteDecision::Fanout(members) =>
      {
        "ok": @json.Json(true),
        "decision": @json.Json("fanout"),
        "members": json_strings(members),
      }
    @aip.RouteDecision::Reject(why) =>
      {
        "ok": @json.Json(false),
        "decision": @json.Json("reject"),
        "reason": @json.Json(why),
      }
  }
  decision.stringify()
}

///|
/// 工具描述校验与 MCP 单源映射（GB/Z 185.7）：binding_kind = native | mcp
#export_name("tool_descriptor_check")
pub fn tool_descriptor_check(
  name : String,
  description : String,
  schema_json : String,
  binding_kind : String,
  mcp_server : String,
) -> String {
  let schema = @json.parse(schema_json) catch {
    _ => return error_json("invalid schema JSON")
  }
  let binding = if binding_kind == "mcp" {
    @tooling.McpBinding(mcp_server)
  } else {
    @tooling.NativeBinding
  }
  let desc : @tooling.ToolDescriptor = {
    name,
    description,
    input_schema: schema,
    binding,
  }
  if !desc.validate() {
    return error_json(
      "invalid descriptor (name/description empty or schema not object)",
    )
  }
  let j : @json.Json = {
    "ok": @json.Json(true),
    "valid": @json.Json(true),
    "mcp_entry": desc.to_mcp_entry(),
  }
  j.stringify()
}
