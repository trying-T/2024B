# 问题二：随机生产闭环 + 蒙特卡洛 + 遗传算法（MATLAB）

在 MATLAB 中运行：

```matlab
cd 第二问
test_problem2_model;
outputs = run_problem2_experiment();
```

染色体格式为 `x1x2|yz|r1r2|u1u2`。其中 `x` 表示新购零件检测，`y` 表示成品检测，`z` 表示拆解，`r` 表示回收件检测，`u` 表示回收件利用。

完整实验默认采用种群规模 100、200 代、交叉概率 0.8、变异概率 0.03、每次适应度 5000 次蒙特卡洛、10 次独立 GA，以及 100000 次最终复评。结果保存在 `results/`。
