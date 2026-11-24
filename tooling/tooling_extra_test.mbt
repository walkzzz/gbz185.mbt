// GB/Z 185.7 工具注册表查询测试（names 确定性顺序 / is_registered 生命周期）

///|
fn desc_of(name : String) -> @tooling.ToolDescriptor {
  {
    name,
    description: "d",
    input_schema: Json::empty_object(),
    binding: @tooling.NativeBinding,
  }
}

///|
fn echo_handler(_inv : @tooling.ToolInvocation) -> @tooling.ToolOutcome {
  @tooling.Completed(Json::empty_object())
}

///|
test "names use shortlex order and track registration" {
  let reg = @tooling.ToolRegistry::new()
  reg.register(desc_of("alpha"), echo_handler) catch {
    _ => panic()
  }
  reg.register(desc_of("zeta"), echo_handler) catch {
    _ => panic()
  }
  // MoonBit String Compare 为 shortlex（长度优先）：zeta(4) 先于 alpha(5)，
  // 与注册顺序相反 → 该断言同时守护「确实排序」，而非依赖插入顺序
  assert_eq(reg.names(), ["zeta", "alpha"])
  assert_true(reg.is_registered("alpha"))
  assert_false(reg.is_registered("beta"))
  reg.unregister("alpha") catch {
    _ => panic()
  }
  assert_false(reg.is_registered("alpha"))
  assert_eq(reg.names(), ["zeta"])
}
