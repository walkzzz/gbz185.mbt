# 已知边界与缺口（真话台账）

> 维护者人工维护的诚实台账：记录已知缺口与平台边界，避免"宣传面与事实面漂移"。
> README 只描述能力；本文件描述边界。评审/集成前请先读此页。

## 平台与工具链

| 编号 | 描述 | 影响面 | 状态/规避 |
| --- | --- | --- | --- |
| GAP-1 | Windows 本地 `moon prove` 触发 moon 工具链 `\\?` mkdir 平台 bug（EACCES/EINVAL），证明目录创建失败；与 Z3 安装无关 | Windows 开发者本地跑 prove | **规避：WSL 通道**（moon 0.1.20261117 + Z3 4.8.12）3 goals proved 复验通过；CI prove 走 ubuntu runner。待 moon 工具链修复后关闭 |
| GAP-2 | mTLS 双向客户端证书受 @tls API 限制 | transport_async 安全面 | 等效实现：对端证书 SHA-256 指纹钉扎（`peer_cert_fingerprint`） |

## 功能边界

| 编号 | 描述 | 影响面 | 状态 |
| --- | --- | --- | --- |
| GAP-3 | 互联模式 MQ 分发与国密套件（SM2/SM3/SM4）未实现 | 185.6 生产部署 | 0.2.0 路线图（mooncry 原语已就绪，见 CHANGELOG） |
| GAP-4 | 协议栈为库形态：不含协议端点服务、编码侧与 UI | 集成方预期 | 定位即库；服务端组装属上层应用（主工程 agentskills.mbt） |

## 测试口径

- 77/77 为 **native 目标**实测（2026-11-18，seed 固定可复现）；js/wasm/wasm-gc 以 `moon check --deny-warn` 为门。
- 覆盖率 94.8%（78/1503 未覆盖，集中防御分支）；CRAP 全函数 < 10；变异 12/12 KILLED。
- 基准实测（2026-11-18）：dispatch 90.51ns / registry_lookup 96.29ns / envelope_roundtrip 1.69µs。
