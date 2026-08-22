# 问题三：分层随机生产闭环 + 蒙特卡洛 + 遗传算法（MATLAB）

装配拓扑：零件 1–3 组成半成品1，零件 4–6 组成半成品2，零件 7–8 组成半成品3，三个半成品装配为成品。

染色体格式：

```text
X(8)|H(3)|Y|D(3)|Z|R(8)|U(8)|S(3)|V(3)
```

- `X`：新购零件检测；`H`：半成品检测；`Y`：成品检测。
- `D`：不合格半成品拆解；`Z`：不合格成品拆解。
- `R/U`：回收零件检测/利用；`S/V`：回收半成品检测/利用。

基础测试及单进程运行：

```matlab
cd 第三问
test_problem3_model;
outputs = run_problem3_experiment();
```

默认实验采用种群 80、100 代、适应度样本 1200、6 次独立 GA；分作业汇总流程将各次优胜候选用 300000 次独立仿真统一复评。结果保存在 `results/`。

MATLAB R2025b 在部分 Apple Silicon 系统上长时间 JIT 运行可能不稳定。本次正式实验采用关闭加速器、逐作业保存检查点的方式：

```matlab
feature('accel','off')
run_problem3_ga_job("base", 1)         % 基础作业1至6
run_problem3_ga_job("defect_-20%", 1) % 四类敏感性各1至3
finalize_problem3_jobs
```
