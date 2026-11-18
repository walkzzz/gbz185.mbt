// GB/Z 185 wire 层：统一错误契约（特征系统）——全栈各协议包统一实现/依赖
// GB/Z 185 wire layer: unified error contract (trait system) — implemented/depended on by all protocol packages across the stack

///|
/// ProtocolError 特征：GB/Z 185 全栈统一错误契约（方法系统：各协议 suberror 实现 part/code/message）
/// pub(open)：允许协议栈各包（registry/aip/tooling）跨包实现
/// ProtocolError trait: the GB/Z 185 stack-wide unified error contract (method system: protocol suberrors implement part/code/message); pub(open) for cross-package implementations.
pub(open) trait ProtocolError {
  /// 国标部分号（如 "gbz185.6"）
  /// GB/Z part number (e.g. "gbz185.6").
  fn part(Self) -> String
  /// 错误码（如 "AIP-1001"）
  /// Error code (e.g. "AIP-1001").
  fn code(Self) -> String
  /// 错误消息
  /// Error message.
  fn message(Self) -> String
}

///|
/// wire 层 JSON 编解码错误（各包 from_json 统一 raise 类型）
/// wire-layer JSON codec errors (the unified raise type for from_json across packages).
pub(all) suberror JsonWireError {
  MissingField(String)
  BadType(String, String)
  BadValue(String, String)
}

///|
pub impl Show for JsonWireError with fn output(self, logger) -> Unit {
  match self {
    MissingField(f) => logger.write_string("wire/missing-field: \{f}")
    BadType(f, want) => logger.write_string("wire/bad-type: \{f} wants \{want}")
    BadValue(f, v) => logger.write_string("wire/bad-value: \{f} = \{v}")
  }
}

///|
pub impl ToJson for JsonWireError with fn to_json(self) -> Json {
  match self {
    MissingField(f) => { "kind": "missing-field", "field": f }
    BadType(f, want) => { "kind": "bad-type", "field": f, "want": want }
    BadValue(f, v) => { "kind": "bad-value", "field": f, "value": v }
  }
}

///|
pub impl ProtocolError for JsonWireError with fn part(_self) -> String {
  "gbz185.wire"
}

///|
pub impl ProtocolError for JsonWireError with fn code(self) -> String {
  match self {
    MissingField(_) => "WIRE-1001"
    BadType(_, _) => "WIRE-1002"
    BadValue(_, _) => "WIRE-1003"
  }
}

///|
pub impl ProtocolError for JsonWireError with fn message(self) -> String {
  match self {
    MissingField(f) => "missing field \{f}"
    BadType(f, want) => "field \{f} expects \{want}"
    BadValue(f, v) => "bad value for \{f}: \{v}"
  }
}

///|
pub extend JsonWireError with Show::{to_string, output}

///|
pub extend JsonWireError with @moonbitlang/core/json.ToJson::{to_json}

///|
pub extend JsonWireError with ProtocolError::{part, code, message}
