function test_problem3_model()
%TEST_PROBLEM3_MODEL 问题三基础回归测试。

scenario = problem3_params();
assert(isequal(scenario.componentGroups, {1:3, 4:6, 7:8}));
zeroStrategy = decode_problem3_chromosome(zeros(1, 38));
first = simulate_problem3_strategy(scenario, zeroStrategy, 1000, 123);
second = simulate_problem3_strategy(scenario, zeroStrategy, 1000, 123);
assert(isequal(first, second), '固定种子结果不可复现。');
assert(first.completionRate == 1, '零策略应在循环上限内完成。');
assert(first.meanFinalAssemblies >= 1);

allStrategy = decode_problem3_chromosome(ones(1, 38));
assert(all(allStrategy.inspectNew == 1));
assert(all(allStrategy.inspectSemi == 1));
assert(all(allStrategy.reuseRecoveredParts == 1));
assert(all(allStrategy.reuseRecoveredSemis == 1));
fprintf('全部问题三 MATLAB 基础测试通过；零策略收益 %.4f。\n', first.meanProfit);
end

