// GB/Z 185.6 AIP 错误分型（E3）——实现 wire.ProtocolError 统一契约（重叠钉扎 #4）

///|
pub(all) suberror AipError {
  Discovery(String)
  Registry(String)
  Capability(String)
  Dispatch(String)
  Envelope(String)
}

///|
pub impl Show for AipError with fn output(self, logger) -> Unit {
  match self {
    Discovery(m) => logger.write_string("aip/discovery: \{m}")
    Registry(m) => logger.write_string("aip/registry: \{m}")
    Capability(m) => logger.write_string("aip/capability: \{m}")
    Dispatch(m) => logger.write_string("aip/dispatch: \{m}")
    Envelope(m) => logger.write_string("aip/envelope: \{m}")
  }
}

///|
pub impl ToJson for AipError with fn to_json(self) -> Json {
  match self {
    Discovery(m) => { "part": "gbz185.6", "kind": "discovery", "message": m }
    Registry(m) => { "part": "gbz185.6", "kind": "registry", "message": m }
    Capability(m) => { "part": "gbz185.6", "kind": "capability", "message": m }
    Dispatch(m) => { "part": "gbz185.6", "kind": "dispatch", "message": m }
    Envelope(m) => { "part": "gbz185.6", "kind": "envelope", "message": m }
  }
}

///|
pub impl @wire.ProtocolError for AipError with fn part(_self) -> String {
  "gbz185.6"
}

///|
pub impl @wire.ProtocolError for AipError with fn code(self) -> String {
  match self {
    Discovery(_) => "AIP-6001"
    Registry(_) => "AIP-6002"
    Capability(_) => "AIP-6003"
    Dispatch(_) => "AIP-6004"
    Envelope(_) => "AIP-6005"
  }
}

///|
pub impl @wire.ProtocolError for AipError with fn message(self) -> String {
  match self {
    Discovery(m) => "discovery error \{m}"
    Registry(m) => "registry error \{m}"
    Capability(m) => "capability error \{m}"
    Dispatch(m) => "dispatch error \{m}"
    Envelope(m) => "envelope error \{m}"
  }
}

///|
/// 错误域映射（原语归属：发现=185.5、注册=185.3、其余=185.6）
pub fn AipError::error_domain(self : AipError) -> String {
  match self {
    Discovery(_) => "gbz185.5"
    Registry(_) => "gbz185.3"
    Capability(_) => "gbz185.4"
    Dispatch(_) => "gbz185.6"
    Envelope(_) => "gbz185.6"
  }
}

///|
pub extend AipError with Show::{to_string, output}

///|
pub extend AipError with @moonbitlang/core/json.ToJson::{to_json}

///|
pub extend AipError with @wire.ProtocolError::{part, code, message}
