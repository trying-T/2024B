function scenarios = problem4_lhs(lower, upper, scenarioCount, seed)
%PROBLEM4_LHS 不依赖统计工具箱的拉丁超立方区间情景。

lower = lower(:)';
upper = upper(:)';
assert(numel(lower) == numel(upper), '上下界维数必须一致。');
assert(all(lower <= upper), '区间下界不能超过上界。');
assert(scenarioCount >= 1 && scenarioCount == floor(scenarioCount), ...
    'scenarioCount必须为正整数。');

previousState = rng;
cleanup = onCleanup(@() rng(previousState)); %#ok<NASGU>
rng(seed, 'twister');
dimension = numel(lower);
unit = zeros(scenarioCount, dimension);
for j = 1:dimension
    permutation = randperm(scenarioCount)';
    unit(:, j) = (permutation - rand(scenarioCount, 1)) / scenarioCount;
end
scenarios = lower + unit .* (upper - lower);
end
