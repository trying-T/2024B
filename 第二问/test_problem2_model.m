function test_problem2_model()
%TEST_PROBLEM2_MODEL 基础回归测试。

strategies = enumerate_strategies(2);
assert(size(strategies, 1) == 80);
scenarios = problem2_params();
strategy = decode_chromosome(zeros(1, 8), 2);
first = simulate_strategy(scenarios(1), strategy, 2000, 123);
second = simulate_strategy(scenarios(1), strategy, 2000, 123);
assert(isequal(first, second), '固定种子结果不可复现。');
assert(first.completionRate == 1, '基准策略应在循环上限内完成。');
assert(first.meanAssemblies >= 1);
assert(first.meanMarketReturns >= 0);
fprintf('全部问题二 MATLAB 基础测试通过；有效策略数：%d。\n', size(strategies, 1));
end

