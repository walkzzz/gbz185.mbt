# gbz185.mbt 在线演示页 全面测试报告

- 目标页面：https://walkzzz.github.io/gbz185.mbt/#start
- 测试方式：真实浏览器（Aha Browser Use / bu 平面）逐项操作 + DOM/可访问性读取 + 网络与控制台监听 + 外部链接状态核验
- 测试时间：2026-11-24（UTC+8）
- 浏览器视口：939 × 872（页面在 924 CSS px 下渲染，页面总高 12281 px）
- 页面版本：标题栏显示 v0.2.0

## 一、结论摘要

页面整体可用性良好：11 个演示函数在初始化时全部执行，10 张演示卡默认用例 10/10 通过，18 个异常输入用例全部返回结构化错误而不崩溃，全程 0 条控制台报错，网络请求仅 3 个同源文件（无任何第三方请求），13 个外部链接全部 HTTP 200。

发现 4 处非阻断性问题，其中 1 处影响导航可用性，1 处影响数值语义保真度：

| 编号 | 级别 | 问题 |
|---|---|---|
| F1 | 中 | 视口 ≤ 960px 时顶部导航整块消失，且无折叠菜单替代 |
| F2 | 中 | 演示层用 `\|0` 强制转 int32，seq 超过 2^31 会回绕、精度丢失 |
| F3 | 低 | 信封校验对空 sender/recipient、seq=0 判为"合法" |
| F4 | 低 | 群组扇出 0 成员返回成功（count 0），与路由卡"空成员即 reject"口径不一致 |

## 二、测试范围与结果

### 1. 功能正确性（10 个演示卡，默认参数）

| 卡片 | 函数 | 期望（页面文档） | 实测 | 结果 |
|---|---|---|---|---|
| 信封编码 | `aip_make_envelope` | 规范化 AIP 信封 | 8 字段齐全，seq 1 / timestamp 1700000000 / kind task_request | 通过 |
| 校验与扇出 | `aip_validate` | 合法判定 | `ok:true`，判词一致 | 通过 |
| 信封元数据 | `aip_envelope_meta` | `sender#seq` | `urn:agent:b#9` | 通过 |
| 序号推进 | `aip_next_seq` | prev 41 → next 42 | `prev 41 / next 42 / monotonic true` | 通过 |
| AIP 完整流程 | `aip_protocol_flow` | 注册→发现→分发→接收 | `is_registered true / outbox_seq 1 / delivered true / peer_watermark 1` | 通过 |
| 能力匹配 | `capability_report` | 缺失诊断 | `covered false / count 2 / missing ["tool:net_fetch"]` | 通过 |
| 发现过滤 | `discovery_match` | 可见性+能力过滤 | `count 1 / urn:agent:a`（隐藏节点 C 被正确排除） | 通过 |
| AIC 身份码 | `identity_aic_check` | 点分十进制+前缀 | `valid true / stack_prefix true` | 通过 |
| 路由解析 | `route_resolve` | 群组展开 | `decision fanout / 2 成员` | 通过 |
| 工具描述 | `tool_descriptor_check` | MCP tools/list 条目 | `valid true`，name/description/inputSchema 齐全 | 通过 |

### 2. 联动与次级操作

- 编码 → 校验/扇出联动：编码结果写入 `#json`，随后点"校验"返回合法、点"群组扇出"返回 `fanout_count 3`，跨卡片数据链路正常。
- 预置按钮：`预置：Event` 置 kind=event、payload `{"event":"agent_online","at":1700000000}`、seq=7；`预置：Heartbeat` 置 kind=heartbeat、payload `{"interval_s":30}`、seq=8，均会立即编码并渲染。seq 显示 7/8（非递增）是预置值所致，不是自增缺陷。
- 扇出成员数：3 → 3；1 → 1；0 → 0（见 F4）。
- 发现过滤取消勾选"仅返回 discoverable"：count 2，返回 `urn:agent:a` 与 `urn:agent:c (hidden)`，勾选逻辑正确。
- 连点稳定性：编码按钮连续点击 8 次，输出保持一致，无重复提交副作用、无控制台报错。

### 3. 异常与边界输入（18 例，全部返回结构化结果）

| 用例 | 实测输出 | 评价 |
|---|---|---|
| seq="abc" | `{"ok":false,"error":"seq / timestamp 必须是数字"}` | 通过 |
| payload 非法 JSON | `{"ok":false,"error":"invalid payload JSON"}` | 通过 |
| sender/recipient 为空 | 编码成功，生成 `sender_urn:""` 信封 | 见 F3 |
| envelope protocol="rpc" | `{"ok":false,"verdict":"非法信封…"}` | 通过 |
| 非法信封下扇出 | `{"ok":false,"error":"无法扇出：信封非法"}` | 通过 |
| 空信封校验 | 非法（不崩溃） | 通过 |
| meta JSON 非法 / kind 未知 | `invalid JSON` / `invalid AIP envelope` | 通过 |
| curseq=i64 最大值 | `prev 9223372036854776000, next 1, monotonic false` | 见 F2 |
| curseq=-3 | `prev -3, next -2, monotonic true`（负数被接受） | 见 F4 备注 |
| peers 为空 | `{"ok":false,"error":"at least one peer URN required"}` | 通过 |
| flow kind=event | 正常投递 | 通过 |
| flow payload 非 JSON | `invalid payload JSON` | 通过 |
| required 为已具备子集 | `covered true, missing []` | 通过 |
| caps 为空 | `count 0, covered false`，缺失清单完整 | 通过 |
| nodes=[] | `count 0`，无异常 | 通过 |
| nodes 非 JSON | `invalid nodes JSON` | 通过 |
| filter 无匹配能力 | `count 0` | 通过 |
| AIC "1.2" / "1.2.156.185.2." / "abc" | `valid true+prefix false` / `valid false+prefix true` / `valid false` | 通过（末段为空判非法，符合"每段非空"） |
| 工具名/描述为空、schema 非法 | `invalid descriptor…` / `invalid schema JSON` | 通过 |
| 工具 binding=native、server 为空 | 仍返回 `mcp_entry`（单源模型的 MCP 视图） | 符合设计 |

### 4. 交互与视觉

- 锚点跳转：首屏"立即试用"→ #demo（scrollY 2038，区块顶部落在 80px）、"快速开始"→ #start（scrollY 8039，顶部 80px），正确避让 64px 吸顶栏。
- 主题切换：点击后 `data-theme` 由 light → dark，图标与 `aria-label` 同步由"切换到深色主题"变为"切换到浅色主题"；刷新后仍为 dark，localStorage 持久化有效。
- 复制按钮：点击后文案变为"已复制"，1.4 秒后自动恢复为"复制"，无报错（剪贴板内容因浏览器权限弹窗未做自动比对）。
- 响应式：939px 宽下 hero 与 demo 卡片均单列（876px 宽），页面无横向溢出（scrollWidth 924 = clientWidth 924）。详见 F1。
- 首屏 playground 计数器：发送序号 1 / 对端水位 1 / 已发现对端 2 / "已投递（receive 校验通过）"，与 `aip_protocol_flow` 返回值一致。

### 5. 健壮性、网络与性能

- 控制台：全流程 0 条 error/warning。
- 网络：仅加载 `index.html`、`style.css`、`app.js`、`playground.js` 四个同源资源，主机名仅 `walkzzz.github.io`，"无后端、无第三方请求"的声明属实。
- 性能：DOMContentLoaded 217ms、load 220ms。
- 外部链接：GitHub 仓库、docs 下 architecture/security/known-gaps/migration/TEST_REPORT/performance/comparison/assessment/proposal 共 9 篇文档，以及 mooncakes.io、CHANGELOG、CONTRIBUTING，全部返回 200。

### 6. 基础可访问性 / 语义

- `lang="zh-CN"`，存在 `.skip-link` 跳转链接。
- 标题层级为单一 H1 + 分节 H2 + 卡片 H3，无跳级、无多 H1。
- 无重复 id；所有 10 张卡的 input/select/textarea 均被 label 包裹或关联；无空文本按钮；无图片（不存在 alt 缺失问题）。
- 键盘：在 #aic 输入框按 Enter 可触发校验（Enter 快捷键映射生效）；可聚焦元素 89 个。

## 三、问题详情

### F1（中）窄屏导航整体缺失

- 现象：`@media (max-width:960px)` 中 `.nav { display:none; }`，实测 924 CSS px 视口下 `.nav` 计算尺寸为 0×0，页面无汉堡菜单、无折叠入口，顶部只剩 brand、主题按钮、GitHub 按钮（见截图 shot-hero.png / shot-demo.png）。六个区块导航（能力/在线演示/快速开始/API/工程质量/文档）在此宽度完全无法到达。
- 影响：常见 13 寸及以下笔电、窗口非最大化时失去全站跳转能力；同时 IntersectionObserver 的高亮逻辑在此宽度无意义。
- 建议：≤960px 增加菜单按钮 + 抽屉/下拉；或改为可横向滚动的导航条（原样式已写了 `.nav` 的 `overflow-x:auto`，只是被 display:none 覆盖）。

### F2（中）演示层 int32 截断与精度丢失

- 现象（信封编码）：`seq=2147483648` → 输出 `seq: -2147483648`；`seq=4294967296` → 输出 `seq: 0`。原因是 `runEncode()` 使用 `Number(seq) | 0`。
- 现象（序号推进）：`curseq=9223372036854775807` → 输出 `prev 9223372036854776000、next 1、monotonic false`，同样是 `cur | 0 = 0` 造成，且 `prev` 以 JS double 显示已失真。
- 影响：页面宣传"i64 语义 / Z3 对 next_seq 的 20 条证明义务"，但演示层只能覆盖 int32 区间，超出即回绕，无法用于验证大序号与防重放边界。
- 建议：要么在 UI 明确标注"演示参数为 int32 范围"，要么改用字符串/BigInt 传参并对 `Number.isSafeInteger` 做前置校验。

### F3（低）空 URN、seq=0 被判为合法信封

- 现象：sender、recipient 留空、seq=0 时，编码成功生成 `sender_urn:""`、`recipient_urn:""`、`seq:0` 的信封；随后"校验"返回 `ok:true，"合法 AIP 信封"`。校验器只检查版本/协议/字段存在/kind，不检查字段语义。
- 影响：与"规范化信封"的表述存在落差，读者容易误判协议校验强度。
- 建议：编码侧拒绝空 URN 与非正 seq，校验侧增加 `sender_urn/recipient_urn` 非空、`seq > 0` 判定，或把判词改为"结构合法（未校验取值）"。

### F4（低）扇出 0 成员的成功口径

- 现象：群组成员留空点"群组扇出"，返回 `{"ok":true,"fanout_count":0}`；而"路由解析"卡在成员为空时返回 `{"ok":false,"decision":"reject","reason":"empty group …"}`。
- 影响：同一"空成员"条件在两张卡上结论相反，容易被理解为扇出可零投递。
- 建议：扇出侧对 0 成员返回错误或明确 `ok:true, fanout_count:0, note:"无成员"`。

补充备注（不计为缺陷）：`aip_next_seq(-3)` 返回 `next -2, monotonic true`，负序号被接受；若序号承担防重放职责，建议在编码/推进侧统一拒绝非正数。

## 四、通过项清单（无问题）

- 10 个演示函数默认用例与文档声明输出一致，初始化即全部执行。
- 18 个异常输入均返回 `{"ok":false,...}`，无异常冒泡、无控制台噪声、无白屏。
- 编码→校验→扇出的跨卡片数据流正确。
- 主题切换与持久化、锚点滚动避让、复制按钮反馈、连点幂等均正常。
- 零第三方请求、零后端调用、加载 220ms，符合页面自述。
- 13 个外部链接全部 200，无死链。
- 语义与可访问性基线良好（lang、skip-link、标题层级、label 全覆盖、无重复 id）。

## 五、建议优先级

1. 先修 F1（影响所有 ≤960px 窗口的真实导航），改动最小、收益最高。
2. 再修 F2（保证"数字可复算 / i64 证明"宣传与演示一致，至少加范围提示）。
3. F3、F4 属口径问题，可与 v0.2.x 的校验器增强合并处理。

## 附：测试证据

- shot-hero.png：首屏（可见 939px 宽下无顶部导航）
- shot-demo.png：信封编码卡片默认输出
- shot-quality.png：质量门禁数字区（124 / 117×3 / 91.8% / 19/19 / 20）
