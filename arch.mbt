// GB/Z 185.1 总体架构（模块根包门面）：双模式、全局模型、角色定义。
// 内容源自上游 agentskills-runtime README 已提取的架构要素（本地模式/互联模式、
// agents/agent_skills/agent_messages/agent_tasks 全局模型、ACPs/CA/发现服务/MQ 角色）。

///|
#derive(Eq, Debug)
pub(all) enum ArchitectureMode {
  LocalMode
  InterconnectMode
}

///|
pub fn ArchitectureMode::name(self : ArchitectureMode) -> String {
  match self {
    LocalMode => "local"
    InterconnectMode => "interconnect"
  }
}

///|
#derive(Eq, Debug)
pub(all) enum GlobalModelEntity {
  AgentEntity
  AgentSkillEntity
  AgentMessageEntity
  AgentTaskEntity
  SessionEntity
}

///|
pub fn GlobalModelEntity::name(self : GlobalModelEntity) -> String {
  match self {
    AgentEntity => "agents"
    AgentSkillEntity => "agent_skills"
    AgentMessageEntity => "agent_messages"
    AgentTaskEntity => "agent_tasks"
    SessionEntity => "sessions"
  }
}

///|
#derive(Eq, Debug)
pub(all) enum InterconnectRole {
  ServiceProvider
  ServiceConsumer
  RegistryCenter
  DiscoveryCenter
  MessageGateway
}

///|
pub fn InterconnectRole::name(self : InterconnectRole) -> String {
  match self {
    ServiceProvider => "service-provider"
    ServiceConsumer => "service-consumer"
    RegistryCenter => "acps-registry"
    DiscoveryCenter => "adp-discovery"
    MessageGateway => "mq-gateway"
  }
}

///|
pub fn stack_part(part : String) -> String {
  "GB/Z 185-\{part}"
}

///|
pub extend ArchitectureMode with Eq::{equal, not_equal}

///|
pub extend ArchitectureMode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GlobalModelEntity with Eq::{equal, not_equal}

///|
pub extend GlobalModelEntity with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend InterconnectRole with Eq::{equal, not_equal}

///|
pub extend InterconnectRole with @moonbitlang/core/debug.Debug::{to_repr}
