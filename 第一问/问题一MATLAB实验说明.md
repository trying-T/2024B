# 问题一 MATLAB 实验

## 运行

在 MATLAB 中将当前文件夹切换到本目录，然后执行：

```matlab
results = problem1_binomial_experiment();
```

默认参数为：`p0=0.1`、`alphaReject=0.05`、`alphaAccept=0.10`、`nMax=1000`、`epsilon=0.01`。推荐规则要求平滑后的标准差相对改善连续 10 次小于 1%。

可以覆盖任意参数，例如：

```matlab
cfg = struct();
cfg.nMax = 500;
cfg.epsilon = 0.005;
cfg.stabilityWindow = 15;
cfg.minRecommendN = 50;
cfg.outputDir = 'results_problem1_custom';
results = problem1_binomial_experiment(cfg);
```

## 输出

运行后生成目录 `results_problem1`，包括：

- `reject_thresholds.csv`：每个样本量的拒收临界值、尾概率、方差和标准差；
- `accept_thresholds.csv`：每个样本量的接收临界值、累积概率、方差和标准差；
- `reject_sigma_curve.png`：拒收模型的 \(n-\sigma_r\) 曲线；
- `accept_sigma_curve.png`：接收模型的 \(n-\sigma_a\) 曲线；
- `experiment_summary.txt`：参数、首个可行样本量和推荐方案。

MATLAB 工作区中的 `results.rejectChoice` 与 `results.acceptChoice` 分别保存最终推荐行。

默认参数下，独立精确计算得到：

| 模型 | 推荐 \(n\) | 临界值 | 约束概率 | \(\sigma\) |
|---|---:|---:|---:|---:|
| 95% 信度拒收 | 85 | \(x_r=14\) | 0.0423103808 | 0.0402313683 |
| 90% 信度接收 | 105 | \(x_a=6\) | 0.0898602089 | 0.0226521419 |

因此对应判定为：抽检 85 件，次品数不少于 14 件时拒收；抽检 105 件，次品数不多于 6 件时接收。这里的推荐值取决于默认的稳定性参数，并不是仅由置信约束唯一确定。

可执行回归测试：

```matlab
test_problem1_binomial_experiment
```

## 判定约定

- 拒收临界值 `xr` 是满足 \(P_{p_0}(X\ge x_r)\le0.05\) 的最小整数；
- 接收临界值 `xa` 是满足 \(P_{p_0}(X\le x_a)\le0.10\) 的最大整数；
- 没有任何可观测临界值满足约束时记为 `NaN`，不虚构 `n+1` 或 `-1` 判定；
- 概率通过 `betainc` 精确计算，不依赖 Statistics and Machine Learning Toolbox。

## 指标解释

代码严格按指定方案计算

\[
\sigma(n)=\sqrt{\frac{(x/n)(1-x/n)}{n}}.
\]

该量是“临界样本比例的标准误”，用于比较检测数量增加后的边际变化。它不是 \(p=p_0\) 时的抽样标准误；后者为 \(\sqrt{p_0(1-p_0)/n}\)。尤其当接收临界值 `xa=0` 时，指定公式会给出零，因此推荐算法只从有限且严格为正的标准差开始判断稳定性。
