// GB/Z 185.1 总体架构门面白盒测试（双模式 / 全局模型 / 互联角色的完整枚举覆盖）

///|
test "architecture modes name both variants" {
  assert_eq(ArchitectureMode::LocalMode.name(), "local")
  assert_eq(ArchitectureMode::InterconnectMode.name(), "interconnect")
}

///|
test "global model entities name all five tables" {
  assert_eq(GlobalModelEntity::AgentEntity.name(), "agents")
  assert_eq(GlobalModelEntity::AgentSkillEntity.name(), "agent_skills")
  assert_eq(GlobalModelEntity::AgentMessageEntity.name(), "agent_messages")
  assert_eq(GlobalModelEntity::AgentTaskEntity.name(), "agent_tasks")
  assert_eq(GlobalModelEntity::SessionEntity.name(), "sessions")
}

///|
test "interconnect roles name all five roles" {
  assert_eq(InterconnectRole::ServiceProvider.name(), "service-provider")
  assert_eq(InterconnectRole::ServiceConsumer.name(), "service-consumer")
  assert_eq(InterconnectRole::RegistryCenter.name(), "acps-registry")
  assert_eq(InterconnectRole::DiscoveryCenter.name(), "adp-discovery")
  assert_eq(InterconnectRole::MessageGateway.name(), "mq-gateway")
}

///|
test "stack part prefixes GB/Z 185" {
  assert_eq(stack_part("185.6"), "GB/Z 185-185.6")
}
