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

## Schema-10 revalidation

新门禁在同一固定种子窗口通过
[nightly run 38384529922](https://github.com/Yingqingxue/moonsmith/actions/runs/38384529922)
（commit `805b87c`）。下载 artifact 后独立复核得到：

- Schema 10；1,000 个唯一程序、1,000 个参考校验、3,000 次 JS/Wasm/Wasm-GC
  执行，零意外结果。
- `&&` 出现在 558 份源码；aggregate 与逐例 trace 对齐：RHS 执行 170 例、
  短路跳过 178 例。
- `||` 出现在 357 份源码；aggregate 与逐例 trace 对齐：RHS 执行 141 例、
  短路跳过 162 例。
- 最大生成源码 242 行。231,604 字节的独立 HTML 报告包含 `casesWithAnd`，
  不含 `<script>` 或 `<img>` 标签。

配套
[跨平台 CI run 38384509956](https://github.com/Yingqingxue/moonsmith/actions/runs/38384509956)
中的 Linux 与 Windows native job 均成功。这些是固定有限语料结果，不是
全语言正确性证明、后端内部 branch coverage 或缺陷发现率估计；没有发现
新的 MoonBit 编译器缺陷。
