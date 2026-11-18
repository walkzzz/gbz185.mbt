// GB/Z 185.7 工具调用黑盒测试（ToolDescriptor 单源 wire 往返 / 绑定 / ToolCallable 契约）

///|
struct EchoTool {}

///|
impl @tooling.ToolCallable for EchoTool with fn invoke(_self, inv) {
  @tooling.Completed(inv.args)
}

///|
extend EchoTool with @tooling.ToolCallable::{invoke}

///|
test "tool descriptor wire roundtrip with mcp binding" {
  let desc = @tooling.ToolDescriptor::{
    name: "file_read",
    description: "read a file under the skill directory",
    input_schema: { "type": "object", "path": "string" },
    binding: @tooling.McpBinding("primary"),
  }
  let back = @tooling.ToolDescriptor::from_json(desc.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, desc)
}

///|
test "tool descriptor wire roundtrip with native binding" {
  let desc = @tooling.ToolDescriptor::{
    name: "cli_execute",
    description: "execute a whitelisted cli command",
    input_schema: { "type": "object" },
    binding: @tooling.NativeBinding,
  }
  let back = @tooling.ToolDescriptor::from_json(desc.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, desc)
}

///|
test "bad binding kind raises wire error" {
  let mut got = false
  try {
    let _ = @tooling.ToolDescriptor::from_json({
      "name": "x",
      "description": "y",
      "input_schema": { "type": "object" },
      "binding": { "kind": "grpc" },
    })
    panic()
  } catch {
    @wire.BadValue(_, _) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "ToolCallable contract via fake tool (绑定契约)" {
  let tool = EchoTool::{ }
  let outcome = tool.invoke(@tooling.ToolInvocation::{
    invocation_id: "i-1",
    tool: "echo",
    args: Json::string("hello"),
  })
  assert_eq(outcome, @tooling.Completed(Json::string("hello")))
}

///|
test "ToolRegistry: register/lookup/count and duplicate rejection" {
  let reg = @tooling.ToolRegistry::new(max_tools=2)
  let desc = @tooling.ToolDescriptor::{
    name: "file_read",
    description: "read files",
    input_schema: { "type": "object" },
    binding: @tooling.NativeBinding,
  }
  let handler = fn(_inv : @tooling.ToolInvocation) -> @tooling.ToolOutcome {
    @tooling.Completed(Json::string("ok"))
  }
  @tooling.ToolRegistry::register(reg, desc, handler) catch {
    _ => panic()
  }
  assert_eq(@tooling.ToolRegistry::count(reg), 1)
  assert_true(@tooling.ToolRegistry::lookup(reg, "file_read") is Some(_))
  let mut got = false
  try {
    @tooling.ToolRegistry::register(reg, desc, handler)
    panic()
  } catch {
    @tooling.DuplicateTool(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "ToolRegistry: validate rejects empty descriptor" {
  let reg = @tooling.ToolRegistry::new()
  let bad = @tooling.ToolDescriptor::{
    name: "",
    description: "",
    input_schema: Json::empty_object(),
    binding: @tooling.NativeBinding,
  }
  let mut got = false
  try {
    @tooling.ToolRegistry::register(reg, bad, fn(_inv) {
      @tooling.Completed(Json::null())
    })
    panic()
  } catch {
    @tooling.InvalidDescriptor(_) => got = true
    _ => panic()
  }
  assert_true(got)
  assert_false(bad.validate())
}

///|
test "ToolRegistry: capacity guard and unregister" {
  let reg = @tooling.ToolRegistry::new(max_tools=1)
  let desc = @tooling.ToolDescriptor::{
    name: "t1",
    description: "d",
    input_schema: { "type": "object" },
    binding: @tooling.NativeBinding,
  }
  let handler = fn(_inv : @tooling.ToolInvocation) -> @tooling.ToolOutcome {
    @tooling.Completed(Json::null())
  }
  @tooling.ToolRegistry::register(reg, desc, handler) catch {
    _ => panic()
  }
  let another = @tooling.ToolDescriptor::{
    name: "t2",
    description: "d",
    input_schema: { "type": "object" },
    binding: @tooling.NativeBinding,
  }
  let mut got = false
  try {
    @tooling.ToolRegistry::register(reg, another, handler)
    panic()
  } catch {
    @tooling.RegistryFull(1) => got = true
    _ => panic()
  }
  assert_true(got)
  @tooling.ToolRegistry::unregister(reg, "t1") catch {
    _ => panic()
  }
  assert_eq(@tooling.ToolRegistry::count(reg), 0)
}

///|
test "invoke_tool: dispatch, unknown tool and audit log" {
  let reg = @tooling.ToolRegistry::new()
  let desc = @tooling.ToolDescriptor::{
    name: "echo",
    description: "echo args",
    input_schema: { "type": "object" },
    binding: @tooling.NativeBinding,
  }
  @tooling.ToolRegistry::register(reg, desc, fn(
    inv : @tooling.ToolInvocation,
  ) -> @tooling.ToolOutcome {
    @tooling.Completed(inv.args)
  }) catch {
    _ => panic()
  }
  let inv = @tooling.ToolInvocation::{
    invocation_id: "i-1",
    tool: "echo",
    args: ("payload" : Json),
  }
  let outcome = @tooling.ToolRegistry::invoke_tool(reg, inv) catch {
    _ => panic()
  }
  assert_eq(outcome, @tooling.Completed(("payload" : Json)))
  // 调用日志（审计关联：invocation_id → outcome）
  let log = @tooling.ToolRegistry::invocation_log(reg)
  assert_eq(log.length(), 1)
  assert_eq(log[0].0.invocation_id, "i-1")
  // 未注册工具 → UnknownTool
  let unknown = @tooling.ToolInvocation::{
    invocation_id: "i-2",
    tool: "nope",
    args: Json::empty_object(),
  }
  let mut got = false
  try {
    let _ = @tooling.ToolRegistry::invoke_tool(reg, unknown)
    panic()
  } catch {
    @tooling.UnknownTool(_) => got = true
    _ => panic()
  }
  assert_true(got)
}

///|
test "invoke_batch: sequential execution with Failed carrying through" {
  let reg = @tooling.ToolRegistry::new()
  let desc = @tooling.ToolDescriptor::{
    name: "echo",
    description: "echo",
    input_schema: { "type": "object" },
    binding: @tooling.NativeBinding,
  }
  @tooling.ToolRegistry::register(reg, desc, fn(
    inv : @tooling.ToolInvocation,
  ) -> @tooling.ToolOutcome {
    @tooling.Completed(inv.args)
  }) catch {
    _ => panic()
  }
  let invs = [
    @tooling.ToolInvocation::{
      invocation_id: "b-1",
      tool: "echo",
      args: ("1" : Json),
    },
    @tooling.ToolInvocation::{
      invocation_id: "b-2",
      tool: "ghost",
      args: Json::empty_object(),
    },
    @tooling.ToolInvocation::{
      invocation_id: "b-3",
      tool: "echo",
      args: ("3" : Json),
    },
  ]
  let outcomes = @tooling.ToolRegistry::invoke_batch(reg, invs[:])
  assert_eq(outcomes.length(), 3)
  // 未注册工具不中断批次（Failed 承载）
  assert_eq(outcomes[1], @tooling.Failed("unknown tool ghost"))
  assert_eq(outcomes[2], @tooling.Completed(("3" : Json)))
  assert_eq(@tooling.ToolRegistry::invocation_log(reg).length(), 3)
}

///|
test "to_mcp_entry: single-source mapping to MCP tools/list (钉扎 #1)" {
  let desc = @tooling.ToolDescriptor::{
    name: "file_read",
    description: "read a file",
    input_schema: { "type": "object", "path": "string" },
    binding: @tooling.McpBinding("primary"),
  }
  let entry = desc.to_mcp_entry()
  assert_eq(
    entry,
    (
      {
        "name": "file_read",
        "description": "read a file",
        "inputSchema": { "type": "object", "path": "string" },
      } : Json),
  )
}
