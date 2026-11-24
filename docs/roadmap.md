# 路线图（gbz185.mbt）

> 维护者：walkzzz。状态以仓库实测为准；每轮完成回写本文与 CHANGELOG。

## 0.2.0 — 立项级增强（2026-11-24，已完成）

- ✅ API 扩充 11 项：身份状态谓词、能力 `count/covers_any/missing`、`AgentNode::matches`、
  注册表 `is_registered/urn_list`、协议状态 `is_registered/outbox_seq/inbox_watermark/peer_urns`、
  `AipEnvelope::message_id`、会话 getter、`RouteTable::is_member`、工具 `is_registered/names`。
- ✅ 能力检索剪枝（需求去重 + 长度剪枝，语义等价，含白盒/属性测试）。
- ✅ 测试 124（native）/ 117 × 3 便携；覆盖率 811/883 = 91.8%（插桩点口径）。
- ✅ 变异矩阵 12 → 19，全部 KILLED。
- ✅ `playground` 导出 4 → 11；Pages 页面改为库首页范式并保留旧钩子。
- ✅ `check_pages.mjs` 18 → 131 项；七篇立项文档。
- ✅ 修正排序声明（MoonBit String Compare = shortlex）。

## 0.2.1 — 页面测试报告整改（2026-11-24，已完成）

- ✅ F1 窄屏（≤960px）汉堡菜单与抽屉导航（`#nav-toggle` / `.nav.open`）。
- ✅ F2 演示层移除 `|0` 截断，改 `Number.isSafeInteger` + int32 范围前置校验（越界报错不回绕）。
- ✅ F3 编码/校验双侧拒绝空 URN、seq ≤ 0、timestamp < 0。
- ✅ F4 扇出 0 成员返回 `-2`，页面与路由卡「空群组拒绝」同口径。
- ✅ 页检 131 → **141**；E2E 17 → **26**（含 939px 窄屏导航与边界输入）。

## 0.2.2 — 第二轮页面测试报告整改（2026-11-24，已完成）

- ✅ R1 元数据卡与校验卡同口径（合法 URN、seq > 0、timestamp ≥ 0；`seq:0` 拒绝）。
- ✅ R2 简化 URN 校验（`urn:` 前缀、≤256、`[A-Za-z0-9._:-]`），覆盖编码/校验/流程/元数据。
- ✅ R3 扇出按 URN 去重（与路由卡一致）+ `aip_fanout_detail`（raw/unique/duplicates/members）。
- ✅ R4 MCP 工具名 `[A-Za-z0-9_-]{1,64}`、description ≤1024。
- ✅ R5 移动菜单 z-index 60 + 展开时关闭顶栏 blur（截图合成缓解，真机目视待用户）。
- ✅ 页检 141 → **159**；E2E 26 → **30**（本地/线上）。

## 0.3.0 — 候选（未排期）

- ⬜ MQ 分发（185.6 互联面）设计评审；
- ⬜ 国密套件（SM2/SM3/SM4）与 `mooncry` 集成评估；
- ⬜ `transport_async` mbti 契约缺口（async API 导出）跟踪工具链修复；
- ⬜ 覆盖率补充至 ≥95%（错误路径与 mock 防御分支）。

## 1.0 — 稳定化条件

- ⬜ 跨版本兼容实证（两版并存升级路径）；
- ⬜ 至少一个外部项目生产使用反馈；
- ⬜ 证明义务随 API 变更同步维护（禁止「证明与实现漂移」）。

## 维护纪律

1. 任何协议语义变更：先改 `docs/TEST_REPORT.md`，再改实现与测试；
2. 任何公开签名变更：同提交 `moon info` 的 `.mbti`；
3. 每轮收口：`moon fmt` / `check` 四目标 / `test` 四目标 / 覆盖率 / 变异 / `check_pages`；
4. 数字以实测为准，README、页面与报告三处口径一致。
