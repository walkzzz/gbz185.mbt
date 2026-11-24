# 性能与资源报告（gbz185.mbt 0.2.0）

> 实测环境：Windows 11 / native release（`moon bench --target native`），2026-11-24。
> 本文只记录**实测**数字；未采集的对比不写倍数。

## 1. 基准结果

| 基准 | 实测（mean ± σ） | 采样 |
| --- | --- | --- |
| `dispatch_pipeline`（185.6 分发） | **122.98 ns ± 8.13 ns** | 10 × 100000 |
| `registry_lookup`（185.3 按 URN 查询） | **81.13 ns ± 7.61 ns** | 10 × 100000 |
| `envelope_wire_roundtrip`（信封 wire 往返） | **1.56 µs ± 103.95 ns** | 10 × 66594 |
| `registry_find_by_capability_1000x8`（1000 节点 × 8 项需求） | **101.59 µs ± 16.57 µs** | 10 × 1190 |

复现：

```bash
moon bench --target native
```

说明：基准文件为 `aip/aip_bench_test.mbt`（`test (b : @bench.T)` 无名测试块）。能力检索基准的数据集为 1000 个已注册节点，其中 200 个具备全部 8 项能力、800 个只有 4 项；结果恒为 200 个匹配（测试内断言）。

## 2. 复杂度

| 操作 | 复杂度 | 说明 |
| --- | --- | --- |
| `TokenRegistry::lookup` / `state` / `last_seen_of` | O(log n) | `Map[String, Entry]` |
| `TokenRegistry::register` | O(log n) | 容量检查 + 写入 |
| `TokenRegistry::find_by_capability` | O(n × k)（最坏），带长度剪枝 | k = 去重需求数 |
| `AgentCapabilitySet::covers` | O(\|required\| × \|caps\|) | 小集合线性最优 |
| `AgentNode::matches` / `match_nodes` | O(n × k × c) | 与 `covers` 同阶 |
| `AipProtocol::dispatch` / `receive` | O(log peers) | 单次 Map 读写 + 纯函数裁决 |
| `RouteTable::resolve` | O(members) | 扇出需复制成员数组（返回值所有权） |
| `fanout` | O(members) | 逐成员构造信封 |

## 3. 能力检索剪枝（严格等价）

`find_by_capability` 先对需求去重（重复项不影响覆盖语义），再以「候选能力条目数 < 需求数」剪枝：

- 覆盖 k 个**互异**需求，候选能力集必须至少有 k 个条目 → 剪枝不丢任何正确结果；
- 去重不改变 `covers` 判定（重复需求只会重复检查同一项）；
- 114 浏览器演示中的 `capability_report` 同样走 `covers` / `missing`，语义与库一致；
- 属性测试断言 `covers(req) ⇔ missing(req) == []`（seed 2031/2032），白盒与黑盒测试分别在 `registry_extra_test.mbt`、`capability_extra_test.mbt` 中锁定等长/超集/短集三类候选。

> 未采集「剪枝前后」同机对比，因此不宣称加速倍数；只报告上表实测绝对耗时。

## 4. 覆盖率口径

- 命令：`moon test --target native --enable-coverage --no-parallelize`，
  然后 `moon coverage report -f full_summary`（仅传核心包 trace）。
- 结果：**811 / 883 插桩点 = 91.8%**（2026-11-24）。
- 排除：`transport_async`（Windows 下 `moon coverage` 对含连字符包名的路径拼接缺陷）、`playground`、`examples`（演示层不参与核心覆盖率）。
- 未覆盖点集中：错误渲染分支、mock 生成器少数防御路径、`protocol` 的部分错误路径。

历史文档中的「94.8%」使用的是不可复现的旧分母（1503），已废弃；本报告口径可逐项复算。

## 5. 资源占用

- 核心包零第三方运行时依赖（仅 MoonBit core）；`transport_async` 为唯一扩展依赖点（`moonbitlang/async`、`cc06b/mooncry`）。
- 协议状态下驻内存为 `Map` 与 `Array`；无全局可变状态、无后台线程、无隐藏缓冲。
- 注册表 / 工具表提供容量上限（默认 1024 / 256），防无界增长。
