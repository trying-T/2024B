function result = simulate_strategy(scenario, strategy, trialCount, seed, options)
%SIMULATE_STRATEGY 蒙特卡洛模拟完整生产—市场—回收闭环。
% 分析单位：完成一件最终合格交付。销售收入只计一次；换货时，
% 题给调换损失与重新生产成本均计入。

arguments
    scenario struct
    strategy struct
    trialCount (1,1) double {mustBeInteger, mustBeGreaterThan(trialCount, 1)}
    seed (1,1) double {mustBeInteger}
    options.MaxCycles (1,1) double {mustBeInteger, mustBePositive} = 100
    options.NoncompletionPenalty (1,1) double {mustBePositive} = 10000
end

previousRandomState = rng;
randomStateCleanup = onCleanup(@() rng(previousRandomState)); %#ok<NASGU>
rng(seed, 'twister');
m = numel(scenario.componentDefectRates);
cost = zeros(trialCount, 1);
assemblies = zeros(trialCount, 1);
marketReturns = zeros(trialCount, 1);
disassemblies = zeros(trialCount, 1);
completed = false(trialCount, 1);
recoveredAvailable = false(trialCount, m);
recoveredGood = false(trialCount, m);

for cycle = 1:options.MaxCycles
    active = find(~completed);
    if isempty(active)
        break;
    end
    nActive = numel(active);
    componentGood = false(nActive, m);

    for j = 1:m
        hasRecovered = recoveredAvailable(active, j);
        componentGood(hasRecovered, j) = recoveredGood(active(hasRecovered), j);
        needNewLocal = find(~hasRecovered);
        needNewGlobal = active(needNewLocal);
        nNew = numel(needNewGlobal);
        if nNew == 0
            continue;
        end

        p = scenario.componentDefectRates(j);
        if strategy.inspectNew(j)
            if p == 0
                drawCount = ones(nNew, 1);
            else
                drawCount = floor(log(rand(nNew, 1)) ./ log(p)) + 1;
            end
            cost(needNewGlobal) = cost(needNewGlobal) + drawCount .* ...
                (scenario.purchaseCosts(j) + scenario.componentInspectionCosts(j));
            componentGood(needNewLocal, j) = true;
        else
            cost(needNewGlobal) = cost(needNewGlobal) + scenario.purchaseCosts(j);
            componentGood(needNewLocal, j) = rand(nNew, 1) >= p;
        end
    end

    recoveredAvailable(active, :) = false;
    cost(active) = cost(active) + scenario.assemblyCost;
    assemblies(active) = assemblies(active) + 1;
    assemblyGood = rand(nActive, 1) >= scenario.finalDefectRate;
    finalGood = all(componentGood, 2) & assemblyGood;

    if strategy.inspectFinal
        cost(active) = cost(active) + scenario.finalInspectionCost;
        completed(active(finalGood)) = true;
        failedLocal = find(~finalGood);
    else
        completed(active(finalGood)) = true;
        failedLocal = find(~finalGood);
        failedGlobal = active(failedLocal);
        marketReturns(failedGlobal) = marketReturns(failedGlobal) + 1;
        cost(failedGlobal) = cost(failedGlobal) + scenario.exchangeLoss;
    end

    if isempty(failedLocal)
        continue;
    end
    failedGlobal = active(failedLocal);
    if strategy.disassemble
        cost(failedGlobal) = cost(failedGlobal) + scenario.disassemblyCost;
        disassemblies(failedGlobal) = disassemblies(failedGlobal) + 1;
        for j = 1:m
            if ~strategy.reuseRecovered(j)
                continue;
            end
            failedPartGood = componentGood(failedLocal, j);
            if strategy.inspectRecovered(j)
                cost(failedGlobal) = cost(failedGlobal) + ...
                    scenario.componentInspectionCosts(j);
                reusable = failedPartGood;
            else
                reusable = true(numel(failedGlobal), 1);
            end
            target = failedGlobal(reusable);
            recoveredAvailable(target, j) = true;
            recoveredGood(target, j) = failedPartGood(reusable);
        end
    end
end

notCompleted = ~completed;
cost(notCompleted) = cost(notCompleted) + options.NoncompletionPenalty;
profit = scenario.salePrice - cost;
meanProfit = mean(profit);
standardDeviation = std(profit, 0);
standardError = standardDeviation / sqrt(trialCount);

result.meanProfit = meanProfit;
result.profitStd = standardDeviation;
result.standardError = standardError;
result.ci95 = meanProfit + [-1, 1] .* 1.96 .* standardError;
result.completionRate = mean(completed);
result.meanAssemblies = mean(assemblies);
result.meanMarketReturns = mean(marketReturns);
result.meanDisassemblies = mean(disassemblies);
end
