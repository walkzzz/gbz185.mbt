// GB/Z 185.7 智能体工具调用：工具描述（ToolDescriptor 单源模型）/调用流程/绑定
// 重叠钉扎 #1（ARCH §2.5）：skills 适配器产出 ToolDescriptor、skills-mcp 映射到 MCP
// tools/list、skills-tools 实现 ToolCallable——单一模型三视图。
// GB/Z 185.7 Agent tool invocation: tool description (ToolDescriptor single-source model), invocation flow, binding
// — overlap pinning #1 (ARCH §2.5): one model, three views — the skills adapter produces ToolDescriptor, skills-mcp maps it to MCP tools/list, skills-tools implements ToolCallable.

///|
/// 工具绑定类型：MCP 面（server 标识）或原生绑定
/// Tool binding: MCP face (server id) or native binding
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
/// ToolDescriptor: the single tool-description model shared by the GB/Z 185.7 and skills domains.
#derive(Eq, Debug)
pub(all) struct ToolDescriptor {
  name : String
  description : String
  input_schema : Json
  binding : ToolBinding
}

///|
/// 工具调用流程：一次调用（invocation_id 用于幂等/审计关联）
/// Tool invocation: one call (invocation_id for idempotency/audit correlation).
#derive(Eq, Debug)
pub(all) struct ToolInvocation {
  invocation_id : String
  tool : String
  args : Json
}

///|
/// 工具调用结果
/// Tool invocation outcome.
#derive(Eq, Debug)
pub(all) enum ToolOutcome {
  Completed(Json)
  Failed(String)
}

///|
/// 工具可调用接口（绑定契约）：skills-tools 的 18 内置工具与技能工具统一实现
/// Invokable tool interface (binding contract): implemented uniformly by the 18 skills-tools built-ins and skill tools.
pub(open) trait ToolCallable {
  fn invoke(Self, ToolInvocation) -> ToolOutcome
}

///|
/// wire 编解码（供 ACPs 能力描述与 AIP 信封互通）
/// wire codec (for ACPs capability description and AIP envelope interoperability).
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
