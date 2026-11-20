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
/// 校验 AIP 信封 JSON（版本/协议/字段/消息类型）
#export_name("aip_validate")
pub fn aip_validate(json : String) -> Bool {
  try {
    let parsed = @json.parse(json)
    let _ = @aip.AipEnvelope::from_json(parsed)
    true
  } catch {
    _ => false
  }
}

///|
/// 群组扇出：返回展开后的信封数（成员以逗号分隔）
#export_name("aip_fanout_count")
pub fn aip_fanout_count(json : String, members_csv : String) -> Int32 {
  try {
    let parsed = @json.parse(json)
    let env = @aip.AipEnvelope::from_json(parsed)
    let members : Array[String] = []
    for m in members_csv.split(",") {
      let s = m.to_owned().trim(chars=" ").to_owned()
      if s.length() > 0 {
        members.push(s)
      }
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
