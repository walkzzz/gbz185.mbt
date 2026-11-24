// GB/Z 185.7 智能体工具调用：工具描述（ToolDescriptor 单源模型）/调用流程/绑定/工具注册表
// 重叠钉扎 #1（ARCH §2.5）：skills 适配器产出 ToolDescriptor、skills-mcp 映射到 MCP
// tools/list、skills-tools 实现 ToolCallable——单一模型三视图。
// 动态注册采用函数值注入（MoonBit 无运行时 trait 对象；ToolCallable 为静态分发契约）。

///|
/// 工具绑定类型：MCP 面（server 标识）或原生绑定
#derive(Eq, Debug)
pub(all) enum ToolBinding {
  McpBinding(String)
  NativeBinding
}

///|
pub extend ToolBinding with Eq::{equal, not_equal}

///|
pub extend ToolBinding with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// ToolDescriptor：唯一工具描述模型（185.7 + skills 两域共用）
#derive(Eq, Debug)
pub(all) struct ToolDescriptor {
  name : String
  description : String
  input_schema : Json
  binding : ToolBinding
}

///|
/// 工具调用流程：一次调用（invocation_id 用于幂等/审计关联）
#derive(Eq, Debug)
pub(all) struct ToolInvocation {
  invocation_id : String
  tool : String
  args : Json
}

///|
/// 工具调用结果
#derive(Eq, Debug)
pub(all) enum ToolOutcome {
  Completed(Json)
  Failed(String)
}

///|
/// 工具可调用接口（静态分发契约）：skills-tools 的 18 内置工具统一实现
pub(open) trait ToolCallable {
  fn invoke(Self, ToolInvocation) -> ToolOutcome
}

///|
/// 描述校验（GB/Z 185.7）：name/description 非空、input_schema 必须为 JSON 对象
pub fn ToolDescriptor::validate(self : ToolDescriptor) -> Bool {
  if self.name.length() == 0 {
    return false
  }
  if self.description.length() == 0 {
    return false
  }
  match self.input_schema {
    Object(_) => true
    _ => false
  }
}

///|
/// MCP tools/list 条目单源映射（钉扎 #1：skills-mcp 由此生成，不得另建模型）
pub fn ToolDescriptor::to_mcp_entry(self : ToolDescriptor) -> Json {
  {
    "name": Json(self.name),
    "description": Json(self.description),
    "inputSchema": self.input_schema,
  }
}

///|
/// wire 编解码（供 ACPs 能力描述与 AIP 信封互通）
pub fn ToolDescriptor::to_json(self : ToolDescriptor) -> Json {
  let binding_json = match self.binding {
    McpBinding(server) => { "kind": "mcp", "server": server }
    NativeBinding => { "kind": "native" }
  }
  {
    "name": Json(self.name),
    "description": Json(self.description),
    "input_schema": self.input_schema,
    "binding": binding_json,
  }
}

///|
pub fn ToolDescriptor::from_json(
  j : Json,
) -> ToolDescriptor raise @wire.JsonWireError {
  let name = @wire.json_string_field(j, "name")
  let description = @wire.json_string_field(j, "description")
  let input_schema = @wire.json_object_field(j, "input_schema")
  let binding_j = @wire.json_object_field(j, "binding")
  let binding = match binding_j {
    Object(fields) =>
      match fields.get("kind") {
        Some(String("mcp")) =>
          match fields.get("server") {
            Some(String(server)) => McpBinding(server)
            _ => raise MissingField("binding.server")
          }
        Some(String("native")) => NativeBinding
        Some(String(other)) => raise BadValue("binding.kind", other)
        Some(_) => raise BadType("binding.kind", "string")
        None => raise MissingField("binding.kind")
      }
    _ => raise BadType("binding", "object")
  }
  { name, description, input_schema, binding, }
}

///|
pub extend ToolDescriptor with Eq::{equal, not_equal}

///|
pub extend ToolDescriptor with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ToolInvocation with Eq::{equal, not_equal}

///|
pub extend ToolInvocation with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ToolOutcome with Eq::{equal, not_equal}

///|
pub extend ToolOutcome with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub(all) suberror ToolingError {
  UnknownTool(String)
  DuplicateTool(String)
  RegistryFull(Int32)
  InvalidDescriptor(String)
}

///|
pub impl Show for ToolingError with fn output(self, logger) -> Unit {
  match self {
    UnknownTool(t) => logger.write_string("tooling/unknown-tool: \{t}")
    DuplicateTool(t) => logger.write_string("tooling/duplicate-tool: \{t}")
    RegistryFull(n) => logger.write_string("tooling/registry-full: \{n}")
    InvalidDescriptor(t) =>
      logger.write_string("tooling/invalid-descriptor: \{t}")
  }
}

///|
pub impl @wire.ProtocolError for ToolingError with fn part(_self) -> String {
  "gbz185.7"
}

///|
pub impl @wire.ProtocolError for ToolingError with fn code(self) -> String {
  match self {
    UnknownTool(_) => "TOOL-7001"
    DuplicateTool(_) => "TOOL-7002"
    RegistryFull(_) => "TOOL-7003"
    InvalidDescriptor(_) => "TOOL-7004"
  }
}

///|
pub impl @wire.ProtocolError for ToolingError with fn message(self) -> String {
  match self {
    UnknownTool(t) => "unknown tool \{t}"
    DuplicateTool(t) => "duplicate tool \{t}"
    RegistryFull(n) => "tool registry full (\{n})"
    InvalidDescriptor(t) => "invalid descriptor \{t}"
  }
}

///|
pub extend ToolingError with Show::{to_string, output}

///|
pub extend ToolingError with @wire.ProtocolError::{part, code, message}

///|
/// 注册表条目（内部）：描述 + 函数值 handler（MoonBit 无运行时 trait 对象，动态注册用闭包注入）
priv struct ToolEntry {
  descriptor : ToolDescriptor
  handler : (ToolInvocation) -> ToolOutcome
}

///|
/// 工具注册表：注册/注销/分发/调用日志（GB/Z 185.7 调用流程的生产级实现）
pub struct ToolRegistry {
  priv tools : Map[String, ToolEntry]
  priv log : Array[(ToolInvocation, ToolOutcome)]
  priv max_tools : Int32
}

///|
/// 构造：max_tools 容量防护（默认 256）
pub fn ToolRegistry::new(max_tools~ : Int32 = 256) -> ToolRegistry {
  { tools: Map([]), log: [], max_tools, }
}

///|
pub fn ToolRegistry::count(self : ToolRegistry) -> Int32 {
  self.tools.length()
}

///|
pub fn ToolRegistry::capacity(self : ToolRegistry) -> Int32 {
  self.max_tools
}

///|
pub fn ToolRegistry::lookup(
  self : ToolRegistry,
  name : String,
) -> ToolDescriptor? {
  match self.tools.get(name) {
    Some(e) => Some(e.descriptor)
    None => None
  }
}

///|
/// 是否已注册（查询不改变注册表）
pub fn ToolRegistry::is_registered(self : ToolRegistry, name : String) -> Bool {
  self.tools.get(name) is Some(_)
}

///|
/// 工具名清单（shortlex 确定性顺序：MoonBit String Compare 先长度后逐字符；
/// 未注册顺序无关，便于 MCP tools/list 与运维诊断的稳定输出）
/// Tool-name list (shortlex deterministic order — MoonBit's String Compare is length-first;
/// independent of registration order, stable output for MCP tools/list and diagnostics).
pub fn ToolRegistry::names(self : ToolRegistry) -> Array[String] {
  let out : Array[String] = []
  for name, _e in self.tools {
    out.push(name)
  }
  out.sort()
  out
}

///|
/// 描述清单快照（MCP tools/list 的数据源）
pub fn ToolRegistry::descriptors(self : ToolRegistry) -> Array[ToolDescriptor] {
  let out : Array[ToolDescriptor] = []
  for _name, e in self.tools {
    out.push(e.descriptor)
  }
  out
}

///|
/// 注册（重名拒绝 + 容量防护 + 描述校验）
pub fn ToolRegistry::register(
  self : ToolRegistry,
  descriptor : ToolDescriptor,
  handler : (ToolInvocation) -> ToolOutcome,
) -> Unit raise ToolingError {
  if !descriptor.validate() {
    raise InvalidDescriptor(descriptor.name)
  }
  if self.tools.get(descriptor.name) is Some(_) {
    raise DuplicateTool(descriptor.name)
  }
  if self.tools.length() >= self.max_tools {
    raise RegistryFull(self.tools.length())
  }
  self.tools[descriptor.name] = { descriptor, handler, }
}

///|
pub fn ToolRegistry::unregister(
  self : ToolRegistry,
  name : String,
) -> Unit raise ToolingError {
  if !self.is_registered(name) {
    raise UnknownTool(name)
  }
  let _ = self.tools.remove(name)
}

///|
/// 调用流程（GB/Z 185.7）：查表 → 分发 → 记录调用日志（幂等 id 由调用方保证）
pub fn ToolRegistry::invoke_tool(
  self : ToolRegistry,
  inv : ToolInvocation,
) -> ToolOutcome raise ToolingError {
  let entry = match self.tools.get(inv.tool) {
    Some(e) => e
    None => raise UnknownTool(inv.tool)
  }
  let outcome = (entry.handler)(inv)
  self.log.push((inv, outcome))
  outcome
}

///|
/// 批量调用（顺序执行，逐个记录日志；错误经 ToolOutcome.Failed 承载不中断批次）
pub fn ToolRegistry::invoke_batch(
  self : ToolRegistry,
  invs : ArrayView[ToolInvocation],
) -> Array[ToolOutcome] {
  let out : Array[ToolOutcome] = []
  for inv in invs {
    let outcome = match self.tools.get(inv.tool) {
      Some(e) => (e.handler)(inv)
      None => Failed("unknown tool \{inv.tool}")
    }
    self.log.push((inv, outcome))
    out.push(outcome)
  }
  out
}

///|
/// 调用日志快照（GB/Z 185.7 审计关联：invocation_id → outcome）
pub fn ToolRegistry::invocation_log(
  self : ToolRegistry,
) -> Array[(ToolInvocation, ToolOutcome)] {
  let out : Array[(ToolInvocation, ToolOutcome)] = []
  for pair in self.log {
    out.push(pair)
  }
  out
}

///|
pub fn ToolRegistry::clear_log(self : ToolRegistry) -> Unit {
  self.log.clear()
}
