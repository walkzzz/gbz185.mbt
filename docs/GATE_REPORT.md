# 上游库质量门禁报告

- 评审对象：walkzzz/gbz185.mbt @ 0.1.0（GB/Z 185.1-185.7 协议栈全栈，10 包，2026-11-17 准入评审）
- 门禁结论：**PASS（优秀 ≥85）**
- 一票否决：**0/7 命中**
- 评分：**86/100**
  - 契约稳定 14/20 | 单一职责 12/12 | 测试覆盖 12/12 | 依赖可控 10/10
  - 错误处理 10/10 | 文档完整 7/10 | 维护性 7/10 | 性能资源 5.6/8 | 低侵入扩展 8/8
- 定级：**优秀（≥85）—— 可作为团队核心公共依赖，全范围推广**
- 阻断项：无
- 整改项：见 §3（4 项限期整改，均为补优性质，不阻断）
- 依据：一票否决 V1-V7 / 11 维度判定要点（upstream-library-quality-gate）

## 1. Step 1 一票否决筛查（V1-V7）

| # | 检查项 | 结果 | 证据 |
| --- | --- | --- | --- |
| V1 | 小版本破坏性变更 | **否** | 0.1.0 首版；`.mbti` 契约门禁已建（moon info 全包生成），SemVer 0.x 声明 |
| V2 | 静默吞异常 | **否** | 全栈类型化错误（`JsonWireError`/`AipError`/`RegistryError` 分型 suberror + `ProtocolError` 统一契约），无裸 abort、无吞错 |
| V3 | 已知高危漏洞 | **否** | 核心零 mooncakes 依赖（仅 MoonBit core）；无网络/文件面（sans-I/O） |
| V4 | 强侵入全局环境 | **否** | 纯函数库：无全局可变状态、无进程/环境修改、sans-I/O 设计 |
| V5 | 无任何测试保障 | **否** | 47/47 全绿（黑盒/白盒/Fake Transport/quickcheck 属性 seed 固定）；变异测试 10/10 KILLED（主仓 docs/TEST_REPORT.md） |
| V6 | 无任何可用文档 | **否** | README 中英双语（默认中文）、全包 `.mbti` 契约、源码注释中英双语（17 文件头 + 26 API doc）、公开 API 全覆盖 |
| V7 | 长期无人维护 | **否** | walkzzz 活跃维护（2026-11-17 建仓+全栈实现+门禁），维护者与周期见工程文档 Charter |

## 2. Step 2 11 维度评分

| 维度 | 权重 | 档位 | 得分 | 判定依据 |
| --- | --- | --- | --- | --- |
| 契约稳定与向后兼容 | 20 | 良 0.7 | **14** | 0.1.0 首版无历史破坏（V1 不适用）；`.mbti` 契约 diff 门禁 + 重叠钉扎（ToolDescriptor/AgentIdentity 单源）已建；**未到"优"**：尚无跨版本演进实证 |
| 单一职责与边界清晰 | 12 | 优 1.0 | **12** | 一句话可述（GB/Z 185 协议栈 sans-I/O 核心）；按国标分部 10 包、重叠钉扎 7 项（ARCH §2.5）；核心零 mooncakes 依赖、内部高内聚 |
| 测试覆盖与质量保障 | 12 | 优 1.0 | **12** | 47 用例（黑盒/白盒/Fake/quickcheck 属性 seed 固定）；变异测试 10/10 KILLED；覆盖率 93.1%（迁移基线）；边界/非法输入/防重放/生命周期全覆盖 |
| 依赖可控性 | 10 | 优 1.0 | **10** | 核心包零 mooncakes 依赖（仅 core）；transport-async 隔离为唯一 FX 依赖点（spire 式分层）；mooncakes 依赖 3 个且全部官方/社区主流 |
| 错误处理与故障隔离 | 10 | 优 1.0 | **10** | `ProtocolError` 特征（part/code/message）全栈统一；suberror 分型按国标部分号；wire 层/语义层错误分层；边界输入有校验反馈（AIC/信封/字段级）；无静默吞 |
| 文档完整性与易用性 | 10 | 良 0.7 | **7** | README 中英双语（默认中文）+ 安装/快速开始/适用不适用场景；`.mbti` 公开 API 全说明；源码注释中英双语 43 处；**未达优**：缺 examples/ 目录、FAQ/踩坑指南、CHANGELOG |
| 维护性与生命周期 | 10 | 良 0.7 | **7** | 单人活跃维护 + 工程文档门禁流程（Charter/DEV/roadmap）；**未达优**：响应机制/披露渠道未文档化（SECURITY.md 待补） |
| 性能与资源占用 | 8 | 良 0.7 | **5.6** | sans-I/O 无泄漏面；O(log n)/O(n) 算法显式声明；**未达优**：moon bench 基准未实测（PRD §3.1 目标待 W13 回填） |
| 低侵入与可扩展性 | 8 | 优 1.0 | **8** | 无全局污染（纯库）；三个标准扩展点（`CAIVerifier`/`ToolCallable`/Transport trait，均 `pub(open)`）；核心参数默认值合理；扩展不影响主流程 |
| **合计** | | | **85.6 ≈ 86/100** | |

## 3. Step 3 定级与判定

**优秀（≥85）→ PASS**。可作为核心公共依赖全范围推广；以下 4 项限期整改（均为补优，不阻断）：

| # | 整改项 | 期限 | 对应维度 |
| --- | --- | --- | --- |
| 1 | 补 `examples/` 最小可运行示例 + FAQ/踩坑指南 | W7 前 | 文档完整 7→优 |
| 2 | 补 `CHANGELOG.md` / `CONTRIBUTING.md` / `SECURITY.md`（开源套件，COD §7） | 首次 mooncakes 发布前 | 维护性 7→优 |
| 3 | `moon bench` 基准实测（信封编解码/registry 查询/防重放），回填 PRD §3.1 | W13-D2 | 性能资源 5.6→优 |
| 4 | ~~`moon prove` 运行 verify 包证明义务~~ **✅ 已关闭（2026-11-17）**：WSL Ubuntu 内 moon prove + Z3 4.8.12 运行成功——**2 goals proved**（clamp_i64 + next_seq）；next_seq（序号严格递增，防重放契约数学基础）已接入 aip 包 dispatch 真实调用 | ✅ 完成 | 契约稳定（加分项） |

## 4. 发布前流水线状态（mooncakes 发布场景附加）

| 步骤 | 状态 |
| --- | --- |
| 1. 全量自动化测试 | ✅ 47/47（四目标） |
| 2. 代码质量门禁 | ✅ 本报告 PASS |
| 3. 产物构建与校验（发布包纯净） | ⬜ 待 `moon publish --dry-run` 验证 |
| 4. 版本号与变更日志 | ⬜ CHANGELOG 待补（整改项 2） |
| 5. 版本标签 | ⬜ 待打 v0.1.0 |
| 6. 正式发布 | ⬜ **由 walkzzz 亲自执行**（既定约定） |
| 7. 版本文档更新 | ⬜ 发布后同步 mooncakes.io/docs |

## 5. 测试手段清单（多手段已落地）

| 手段 | 落点 | 状态 |
| --- | --- | --- |
| 黑盒契约 | 各包 `*_test.mbt` | ✅ |
| 白盒边界 | `aip/aip_wbtest.mbt` 等 | ✅ |
| Fake/Mock | `aip/fake.mbt`（sans-I/O 直连） | ✅ |
| 属性测试 | `aip/aip_prop_test.mbt`（quickcheck，seed 2026-2030） | ✅ |
| 可执行不变量 | `AipProtocol::invariant` | ✅ |
| 形式化验证 | `verify/` proof_enabled（SMT 待装） | 🔶 义务已生成 |
| 变异测试 | 主仓 `scripts/mutation_test.mbtx`（10/10 KILLED） | ✅ |
| 覆盖率/CRAP | 主仓 `docs/TEST_REPORT.md`（93.1% / <10） | ✅ |
| 本地 LLM 夹具 | `test-fixtures/llm-local.md` 登记 | ✅ |
