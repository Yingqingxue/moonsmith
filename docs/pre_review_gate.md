# MoonSmith 初审防重犯核查（2026-10-10 更新）

本文件是提交前的风险闸门，不是“验收已通过”的清单。上次 MoonCAS 的截图只证明九月报名**初审**被驳回；它不能证明最终参赛或获奖结果。压缩包是一个项目快照，不保证与评审当时看到的仓库完全相同。

## 从 MoonCAS 学到的事实

初审邮件明确写了三点：项目有一定价值；功能边界太窄、有效源码（不含测试）在 300 行以内；建议调研现有 CAS 生态。邮件还允许在 9 月 30 日前更新材料。这是评审明确给出的原因，不应改写成“没有 CI”或“没有发布”。

资料包确有 README、测试、三后端 CI、Mooncakes 发布说明和 Git 历史。按本地简单口径（`digest.mbt`、`store.mbt`、`chunked.mbt` 去掉空行与整行注释），核心约 249 行，其中 SHA-256 实现约 112 行；这不是官方的有效行数算法，但与邮件的“300 行以内”一致。README 同时明确：只有内存后端、固定大小分块，缺少持久化存储、持久化清单、流式哈希和远端后端。因此，文档中的构建缓存、包仓库、大文件同步主要还是**潜在使用场景**，不是已经接入并证明可用的系统。

项目计划书只笼统区分了对象存储 SDK 与内容寻址语义层；资料包中没有可核查的 CAS 竞品功能对照、设计取舍和基准。不能断言这单独导致驳回，但它与邮件中的生态调研建议直接对应。MoonCAS 的公开仓库与 [Mooncakes 0.1.0](https://mooncakes.io/docs/Yingqingxue/mooncas) 仍可查到，说明“有发布”并不等于“范围足以通过初审”。

## MoonSmith 当前对照

| 风险 | 2026-10-10 观察 | 判定 |
|---|---|---|
| 实现范围 | 在受限纯表达式子集与有界 `for` 循环之上，新增针对 MoonBit #1274 的窄 `#valtype`/`raise` 探针：双精度字段、可引发函数、`try?` 处理、参考模型和 AST 化简 | 这是定向语法探针，不是一般浮点/异常支持；路径仍由参考解释器记录，不是后端运行时覆盖；JS/Wasm/Wasm-GC 有大规模扫描，native 有 10-seed 四目标 smoke batch、100-seed depth-6 与 30-seed depth-8 Windows `cl.exe` 原生扫描及 probe-specific 四目标注入化简，但 native 总体样本仍有限 |
| 有效工作量 | 按相同粗略口径，当前核心与三个 MoonBit 命令约 1,575 行非空非整行注释；宿主 PowerShell 脚本约 1,110 行。不是官方认定 | 不能靠总行数或脚本行数证明 MoonBit 工程深度 |
| 实用证据 | 深度 4/5 全矩阵 200 种子、深度 5 Wasm 专项 300 种子、深度 6 全矩阵 30 种子、深度 6 Wasm 专项 100 种子、深度 7 全矩阵 130 种子、深度 8 全矩阵 130 种子、深度 9 全矩阵 130 种子、深度 10 全矩阵 230 种子，共 1,250 个跨报告核验无重复的程序体、1,245 次参考校验及 2,935 次后端执行；1,245 个案例一致，另 5 个超过 16,300 行的输入被 runner 以 `generator-limit` 拒绝，未送入编译器。深度 5/6/7/8/9/10 探针源码分别出现于 201/300、89/100、128/130、130/130、130/130、230/230，参考路径访问 140/300、69/100、115/130、123/130、126/130、224/230；CI 四目标 probe-specific 注入化简接受 5/10 步，本地三后端扩展回放接受 15 步，复杂度由 39,300 降至 11,014，触发结构保留；近期上游 #1322 的 native debug ICE 已在当前 Linux 工具链复现，release 与 Wasm-GC 控制均通过 | 主链路和化简回放成立；#1322 是上游先报告的案例，不得算作 MoonSmith 发现；本地耗尽当前候选集合不代表全局最小；参考 trace 不是后端覆盖；深度 10 仍有超尺寸生成边界；尚无 MoonSmith 新发现并复核的缺陷 |
| 可审核交付 | [公开仓库](https://github.com/Yingqingxue/moonsmith) 已建立；[CI run 37988791461](https://github.com/Yingqingxue/moonsmith/actions/runs/37988791461) 的 Linux 与 Windows job 均通过；Windows 使用 MSVC `cl.exe` 完成 native 单测（70/70）、100 个 depth-6 不同程序的 native debug/release 配对（200 次执行）、30 个 depth-8 native-debug 程序及 reference/reducer/CLI 集成；Linux 对 10 个不同生成程序执行 JS/Wasm/Wasm-GC/native debug/native release 共 50 次检查且全部一致；Linux/gcc native debug 复现上游 #1322 ICE，Windows/MSVC debug 未复现；artifact 记录 GCC 13.3.0 与 MSVC 19.51.36260 | 远端交付和自动回放已验证；#1322 表现出 runner/compiler 差异，原因未明；本机没有 C 编译器，native 无法本地复现；随机样本比此前扩充但仍有限；MSVC setup action 的 Node 20 弃用警告仍待上游维护 |
| 同类研究 | 新增 [生态对照文档](ecosystem_comparison.md)，并建立 [回归语料](regressions.md)：2 个历史案例及 1 个近期上游 native `#valtype`/enum 报告复现探针 | 初步桌面调研和 3 个有来源案例检查已完成；#1322 是上游先报告的问题，不能算 MoonSmith 发现；样本不足以验证竞争力，尚无外部预审 |

赛事官网对项目规模写的是 **4–10k 有效 MoonBit 行数的参考范围**，同时说明更看重真实可用、边界、文档、测试和维护性；这不是本月经核实的强制及格线。具体十月报名与验收规则仍应以官方十月说明为准。不能为了追行数添加无用代码，也不能拿测试、生成样例、注释或 PowerShell 宿主脚本充作有效 MoonBit 核心实现。

## 提交前必须满足的闸门

1. **交付可见性。** 公开仓库有真实、连续的开发提交；在干净环境从 README 完成安装、运行和至少一次故障回放；远程 CI 有真实通过记录。没有这些证据，不勾选“完成”。
2. **申报范围与实物一致。** 申报书只把已实现并验收的功能写为“当前能力”。每项主张能指向源码、测试和演示。`native`、任意 MoonBit 源码化简、真实缺陷、HTML 报告等未完成时必须列为限制或路线图。
3. **有意义的语义覆盖。** 固定数组、双字段结构体、带载荷枚举穷尽匹配、带捕获局部函数和有界累加 `for` 循环已完成生成、打印、参考求值、化简和 JS/Wasm/Wasm-GC 测试；native 通过 Linux CI 包测试、10 个生成种子的四后端差分 smoke batch、probe-specific 四目标注入化简，以及 Windows `cl.exe` 下 100 个 depth-6 和 30 个 depth-8 种子的原生差分扫描。循环及探针分支路径计数来自参考解释器，不等于后端运行时覆盖；native 尚未达到大规模扫描，任意源码也尚无路径追踪。不能只统计源码里出现了多少构造，也不以凑行数为目标。
4. **工具价值证据。** 固定语料规模和重复率、故障注入检出与化简基准、失败重放稳定性均有原始报告。真实问题必须在新工具链上复测并查重；若没找到，不伪称发现了编译器 bug，但应如实说明竞争力风险。
5. **生态差异说明。** [生态对照文档](ecosystem_comparison.md)已完成首轮桌面研究，分别说明 Csmith、YARPGen、C-Reduce、MoonBit QuickCheck 的目标与边界，并把 MoonSmith 的已实现能力和未验证主张分开。下一步仍需用固定回归语料和外部意见验证定位，不能把“未发现完全相同项目”写成独特性证明。
6. **提前外部预审。** 在材料截止日前，把一页真实能力说明、仓库和演示交给赛事官方渠道询问是否达到本月初审范围；记录回复。若无法得到回复，此项标记“未验证”，不自行推断通过。

当前 1 已部分满足：远端 Linux/Windows 干净 runner 和注入故障回放已通过；本地另验证了三后端 probe-specific 注入与化简，远端 CI 已验证四目标及 Windows MSVC 版本。3 的有界循环和窄 #valtype/raise 探针完成 JS/Wasm/Wasm-GC 三后端大规模检查；native 已通过远端包测试、10-seed 四后端 smoke batch、probe-specific 注入化简和 Windows `cl.exe` 下 100 个 depth-6 加 30 个 depth-8 的差分，本机因缺少 C 编译器不能复跑，且 native 随机样本总量仍有限。4 有一般及 probe-specific 注入检出/化简证据与 2 个公开历史回归样例，但历史案例均非 MoonSmith 发现；仍无 MoonSmith 发现并复核的真实新编译器缺陷。5 已完成首轮桌面调研和 2 个历史案例检查，样本不足以验证竞争力；6（官方预审）仍未完成。2 只能靠最终申报材料审计确认。不要将此风险表的状态当成赛事初审或获奖结论。

更新（2026-10-10）：回归语料现为 2 个历史上游案例加上近期上游 #1322；在 [CI run 37988791461](https://github.com/Yingqingxue/moonsmith/actions/runs/37988791461) 中，#1322 在 Linux/gcc native debug 复现、在 Windows/MSVC native debug 未复现；MoonSmith 的 native-release target 与 Wasm-GC 对照在两边均通过。该问题由上游先报告，runner/compiler 差异原因尚未分析，不能视为已修复或算作 MoonSmith 新发现。

资料依据：用户提供的 MoonCAS 初审截图及 `方向4-MoonCAS-完整资料.zip`；[赛事官网](https://moonbitlang.github.io/OSC2026/)；[MoonCAS GitHub](https://github.com/Yingqingxue/mooncas)。
