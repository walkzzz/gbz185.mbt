// GB/Z 185.6 AIP 路由（Routing）：路由表、群组成员管理、群组扇出（fanout）。
// 术语钉扎（ARCH §2.5）：本包只管「群组地址消息扇出」的协议语义；
// 组内智能体的编排策略属 skills-agent（代码零重叠）。
// AIP routing (GB/Z 185.6): route table, group membership, fanout — protocol semantics only.

///|
/// 路由目标分类（按 recipient URN 解析）
#derive(Eq, Debug)
pub(all) enum RouteTarget {
  Unicast(String)
  Group(String)
  Unknown
}

///|
pub fn RouteTarget::classify(
  recipient : String,
  group_prefix : String,
) -> RouteTarget {
  if recipient.has_prefix(group_prefix) {
    Group(recipient)
  } else if recipient.has_prefix("urn:agent:") {
    Unicast(recipient)
  } else {
    Unknown
  }
}

///|
pub extend RouteTarget with Eq::{equal, not_equal}

///|
pub extend RouteTarget with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 路由决策：直发（单播）/扇出（群组展开为成员列表）/拒绝（未知目标）
#derive(Eq, Debug)
pub(all) enum RouteDecision {
  Direct(String)
  Fanout(Array[String])
  Reject(String)
}

///|
pub extend RouteDecision with Eq::{equal, not_equal}

///|
pub extend RouteDecision with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 路由表：群组成员 + 已知对端
#derive(Debug)
pub struct RouteTable {
  groups : Map[String, Array[String]]
  peers : Map[String, String]
}

///|
pub fn RouteTable::new() -> RouteTable {
  { groups: Map([]), peers: Map([]), }
}

///|
/// 注册群组（重复注册幂等）
pub fn RouteTable::add_group(self : RouteTable, group_urn : String) -> Unit {
  match self.groups.get(group_urn) {
    Some(_) => ()
    None => self.groups[group_urn] = []
  }
}

///|
/// 成员加入群组（群组不存在则先创建；重复加入幂等）
pub fn RouteTable::join(
  self : RouteTable,
  group_urn : String,
  member_urn : String,
) -> Unit {
  self.add_group(group_urn)
  match self.groups.get(group_urn) {
    Some(members) =>
      if !members.contains(member_urn) {
        members.push(member_urn)
      }
    None => ()
  }
}

///|
/// 成员退出群组（返回是否确实移除；群组不存在返回 false）
pub fn RouteTable::leave(
  self : RouteTable,
  group_urn : String,
  member_urn : String,
) -> Bool {
  match self.groups.get(group_urn) {
    Some(members) => {
      let before = members.length()
      let kept = members.iter().filter(fn(m) { m != member_urn }).collect()
      self.groups[group_urn] = kept
      before != kept.length()
    }
    None => false
  }
}

///|
/// 群组成员清单快照
pub fn RouteTable::members(
  self : RouteTable,
  group_urn : String,
) -> Array[String] {
  match self.groups.get(group_urn) {
    Some(members) => members[:].to_owned()
    None => []
  }
}

///|
pub fn RouteTable::group_count(self : RouteTable) -> Int32 {
  self.groups.length()
}

///|
/// 登记已知对端（幂等）
pub fn RouteTable::add_peer(
  self : RouteTable,
  peer_urn : String,
  endpoint : String,
) -> Unit {
  self.peers[peer_urn] = endpoint
}

///|
/// 查询对端端点
pub fn RouteTable::peer_endpoint(
  self : RouteTable,
  peer_urn : String,
) -> String? {
  self.peers.get(peer_urn)
}

///|
/// 路由解析：群组 → 扇出（成员列表）；已知单播 → 直发；其余 → 拒绝
pub fn RouteTable::resolve(
  self : RouteTable,
  recipient : String,
) -> RouteDecision {
  match RouteTarget::classify(recipient, @wire.group_urn_prefix()) {
    Group(group_urn) =>
      match self.groups.get(group_urn) {
        Some(members) =>
          if members.length() == 0 {
            Reject("empty group \{group_urn}")
          } else {
            Fanout(members[:].to_owned())
          }
        None => Reject("unknown group \{group_urn}")
      }
    Unicast(urn) =>
      if self.peers.get(urn) is Some(_) {
        Direct(urn)
      } else {
        Reject("unknown peer \{urn}")
      }
    Unknown => Reject("unroutable recipient \{recipient}")
  }
}

///|
/// 群组扇出：把群组信封展开为逐成员信封（recipient 替换；其余字段保持——
/// 各对端 inbox 序号空间独立，同 seq 合法）
pub fn fanout(
  base : AipEnvelope,
  members : ArrayView[String],
) -> Array[AipEnvelope] {
  let out : Array[AipEnvelope] = []
  for m in members {
    out.push({ ..base, recipient_urn: m, })
  }
  out
}

///|
pub extend RouteTable with @moonbitlang/core/debug.Debug::{to_repr}
