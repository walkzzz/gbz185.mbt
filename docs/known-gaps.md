# 已知边界与缺口（真话台账）

> 维护者人工维护的诚实台账：记录已知缺口与平台边界，避免「宣传面与事实面漂移」。
> README 只描述能力；本文件描述边界。评审/集成前请先读此页。

## 平台与工具链

| 编号 | 描述 | 影响面 | 状态/规避 |
| --- | --- | --- | --- |
| GAP-1 | Windows 本地 `moon prove` 触发 moon 工具链 `\\?` mkdir 平台 bug（EACCES/EINVAL） | Windows 开发者本地跑 prove | **规避：WSL 通道**（Z3 4.8.12）+ CI ubuntu；待工具链修复 |
| GAP-2 | mTLS 双向客户端证书受 `@tls` API 限制 | transport_async 安全面 | 等效实现：对端证书 SHA-256 指纹钉扎（`peer_cert_fingerprint`） |
| GAP-5 | MoonBit `Compare for String` 为 shortlex（先长度后逐字符），`sort()` 不是字典序 | `urn_list` / `peer_urns` / `names` 的排序 | 文档明示 shortlex；需要字典序时自定义比较 |
| GAP-6 | 旧覆盖率「94.8%（78/1503）」分母不可复现 | 质量数字口径 | 已统一为 native 插桩点口径：**811/883 = 91.8%**（2026-11-24） |
| GAP-7 | `transport_async` 的 async API 未出现在 `.mbti`（moon info 对 native-only async 包的导出缺口） | 下游阅读公开契约 | 以源码 doc 为准；核心不受影响；待工具链修复后补契约 |

## 功能边界

| 编号 | 描述 | 影响面 | 状态 |
| --- | --- | --- | --- |
| GAP-3 | 互联模式 MQ 分发与国密套件（SM2/SM3/SM4）未实现 | 185.6 生产部署 | 0.3.0 路线图（mooncry 原语已就绪，见 roadmap） |
| GAP-4 | 协议栈为库形态：不含协议端点服务、编码侧与 UI | 集成方预期 | 定位即库；服务端组装属上层应用 |
| GAP-8 | 审计事件为内存数组，进程退出即失 | 生产审计 | 持久化属上层职责 |
| GAP-9 | 覆盖率未覆盖的 72 个插桩点集中在错误渲染分支、`protocol` 错误路径与 mock 防御分支 | 覆盖率上限 | 0.3.0 目标 ≥95%；不影响已测语义 |
| GAP-10 | 演示层数字参数为 **int32 范围**（seq 1..2147483646 / timestamp 0..2147483647）；越界由页面与 playground 双侧拒绝，不回绕 | 浏览器演示数值边界 | 文案标注「int32 演示范围」；i64 语义由 `verify` 证明覆盖（0.2.1 修复 `|0` 截断） |
| GAP-11 | 演示层 URN 校验为 **RFC 8141 简化子集**（`urn:` 前缀、≤256、`[A-Za-z0-9._:-]`），不含完整 NSS 解析 | 演示输入校验强度 | 0.2.2 起编码/校验/流程/元数据四处统一；完整 URN 解析属上层应用 |

## 测试口径

- 测试：**native 124/124**；**js / wasm / wasm-gc 各 117/117**（差额为 `transport_async` 的 native-only 用例）。2026-11-24 实测。
- 覆盖率：**811/883 = 91.8%**（native 插桩点；`moon coverage report -f full_summary` 显式传 9 个核心 trace；排除 transport_async/playground/examples）。
- 变异：**19/19 KILLED**（`scripts/mutation_test.mbtx`）。
- 基准（2026-11-24，native release）：dispatch 122.98ns / registry_lookup 81.13ns / envelope 往返 1.56µs / find_by_capability 101.59µs（1000 节点 × 8 需求）。
- 证明：**20 obligations / 13 verified functions**（2026-11-19，WSL + Z3 4.8.12）。
- 页面：`node scripts/check_pages.mjs` **159 项 PASS**；CDP 真实浏览器 E2E **30 项 PASS**（含 939px 窄屏导航、int32 越界、非法 URN、meta seq=0、扇出去重、工具名规范）。
