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
