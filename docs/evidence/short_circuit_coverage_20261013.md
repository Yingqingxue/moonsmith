# 短路运算语料门禁（2026-10-13）

## 目标与口径

生成的 `&&` 与 `||` 都把 RHS 放入捕获可变计数器的闭包中，并在源码中
检查实际调用次数。这样即使错误的 eager evaluation 没改变布尔结果，也会
触发 panic。参考解释器另记录每个 case 是否访问了 RHS 执行/跳过路径；这
是参考 trace，不是后端内部 branch coverage。

批量报告 schema 10 保留 schema 7–9 的渲染和跨平台报告读取能力；nightly
门禁仅接受 schema 10。门禁分别要求至少 20% 的固定 corpus 包含 `&&` 和
`||`，要求每个运算符两条 RHS 路径均被访问，并从逐例源码/trace 字段重新
统计后与 aggregate 计数核对。该比例是最低语法采样约束，不是语义覆盖或
发现缺陷概率的保证。

## 先前固定语料基线

在新增 schema 10 门禁前，schema 9 nightly artifact（run
[38371961570](https://github.com/Yingqingxue/moonsmith/actions/runs/38371961570)，
seeds 14990–15989，depth 4）已有这些可复核观测：

- 558/1,000 个程序源码含 `&&`，高于拟定的 200 个下限；
- reference trace 中 RHS 执行 170 例、短路跳过 178 例；逐例 `referencePathKinds`
  重算与 aggregate `referencePathCaseCounts` 一致；
- 同一固定集的 JS/Wasm/Wasm-GC 执行均与参考结果一致，历史报告详情见
  [disjunction corpus evidence](disjunction_corpus_20261013.md)。

这是改门禁前的基线，不可当作 schema 10 已运行的证据。合并后还需重跑
nightly workflow，确认严格校验通过并更新此文档中的新 run 链接与 artifact
数据。即使门禁通过，trace 数仍只代表参考解释器访问路径，不等同于后端
运行时插桩。
