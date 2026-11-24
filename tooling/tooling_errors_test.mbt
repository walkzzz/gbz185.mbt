// tooling 错误分型与工具描述 wire 测试（GB/Z 185.7 全变体 + 绑定编解码错误分支）

///|
test "tooling error variants expose unified contract" {
  let errors : Array[@tooling.ToolingError] = [
    @tooling.UnknownTool("t"),
    @tooling.DuplicateTool("t"),
    @tooling.RegistryFull(256),
    @tooling.InvalidDescriptor("t"),
  ]
  let codes : Array[String] = []
  for e in errors {
    codes.push(e.code())
    assert_eq(e.part(), "gbz185.7")
    assert_true(e.message().length() > 0)
    assert_true(e.to_string().length() > 0)
  }
  assert_eq(codes, ["TOOL-7001", "TOOL-7002", "TOOL-7003", "TOOL-7004"])
}

///|
test "tool descriptor round-trips both bindings" {
  let mcp : @tooling.ToolDescriptor = {
    name: "net_fetch",
    description: "fetch a URL",
    input_schema: { "type": "object" },
    binding: @tooling.McpBinding("server-a"),
  }
  let back = @tooling.ToolDescriptor::from_json(mcp.to_json()) catch {
    _ => panic()
  }
  assert_eq(back, mcp)
  assert_true(mcp.to_mcp_entry().stringify().contains("inputSchema"))

  let native : @tooling.ToolDescriptor = {
    ..mcp,
    binding: @tooling.NativeBinding,
  }
  let native_back = @tooling.ToolDescriptor::from_json(native.to_json()) catch {
    _ => panic()
  }
  assert_eq(native_back, native)
}

///|
test "tool descriptor rejects malformed binding" {
  let cases : Array[(Json, String)] = [
    (
      {
        "name": "t",
        "description": "d",
        "input_schema": {},
        "binding": { "kind": "bogus" },
      },
      "bad-value",
    ),
    (
      {
        "name": "t",
        "description": "d",
        "input_schema": {},
        "binding": { "kind": 1.0 },
      },
      "bad-type",
    ),
    (
      { "name": "t", "description": "d", "input_schema": {}, "binding": {} },
      "missing-field",
    ),
    (
      {
        "name": "t",
        "description": "d",
        "input_schema": {},
        "binding": "native",
      },
      "bad-type",
    ),
  ]
  for pair in cases {
    let doc = pair.0
    let expect = pair.1
    let kind : String = try {
      let _ = @tooling.ToolDescriptor::from_json(doc)
      "unexpected"
    } catch {
      @wire.BadValue(_, _) => "bad-value"
      @wire.BadType(_, _) => "bad-type"
      @wire.MissingField(_) => "missing-field"
    }
    assert_eq(kind, expect)
  }
}

///|
test "mcp binding requires server field" {
  let missing = try {
    let _ = @tooling.ToolDescriptor::from_json({
      "name": "t",
      "description": "d",
      "input_schema": {},
      "binding": { "kind": "mcp" },
    })
    ""
  } catch {
    @wire.MissingField(f) => f
    _ => "unexpected"
  }
  assert_eq(missing, "binding.server")
}

///|
test "descriptor validate rejects empty name or non-object schema" {
  let empty_name : @tooling.ToolDescriptor = {
    name: "",
    description: "d",
    input_schema: Json::empty_object(),
    binding: @tooling.NativeBinding,
  }
  let empty_desc : @tooling.ToolDescriptor = {
    ..empty_name,
    name: "t",
    description: "",
  }
  let bad_schema : @tooling.ToolDescriptor = {
    ..empty_name,
    name: "t",
    description: "d",
    input_schema: ("x" : Json),
  }
  assert_false(empty_name.validate())
  assert_false(empty_desc.validate())
  assert_false(bad_schema.validate())
}
