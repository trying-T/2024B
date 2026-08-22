# 问题四 MATLAB 实验

本目录严格实现已确认的建模口径：

1. 将题目表中的次品率作为样本估计；
2. 按问题一的规则分别求接收、拒收推荐样本量，并取较大者；
3. 用 `x = round(n*p)` 反推样本次品数；
4. 使用 Bonferroni 修正后的 Clopper–Pearson 精确区间构造联合 95% 置信域；
5. 半成品、成品次品率解释为合格投入条件下的工序失效率；
6. 以联合区间上界作为最坏情景；
7. 问题二完全枚举 80 个有效策略，问题三使用原 38 位遗传算法；
8. 蒙特卡洛区间仅用于最终复评，不进入优化目标。

## 运行

```matlab
cd('第四问')
runtests('test_problem4_model.m')
out2 = run_problem4_problem2();
out3 = run_problem4_problem3();
```

若 MATLAB R2025b 在长时间 JIT 运行中出现系统级总线错误，保持全部模型与算法参数不变，改用检查点方式：

```matlab
for k = 1:6
    run_problem4_problem3_ga_job(k);
end
out3 = finalize_problem4_problem3_jobs();
```

每个作业也可以在独立 MATLAB 进程中执行，以避免长时间进程触发 JIT 故障。

也可以运行：

```matlab
outputs = run_problem4_experiment();
```

问题二结果写入 `results_problem2/`，问题三结果写入 `results_problem3/`。
