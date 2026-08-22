function result = simulate_problem3_strategy(scenario, strategy, trialCount, seed, options)
%SIMULATE_PROBLEM3_STRATEGY 两层装配、检测、市场、拆解和回收闭环仿真。

arguments
    scenario struct
    strategy struct
    trialCount (1,1) double {mustBeInteger, mustBeGreaterThan(trialCount, 1)}
    seed (1,1) double {mustBeInteger}
    options.MaxFinalCycles (1,1) double {mustBeInteger, mustBePositive} = 80
    options.MaxSemiAttempts (1,1) double {mustBeInteger, mustBePositive} = 80
    options.NoncompletionPenalty (1,1) double {mustBePositive} = 20000
end

previousRandomState = rng;
randomStateCleanup = onCleanup(@() rng(previousRandomState)); %#ok<NASGU>
rng(seed, 'twister');

n = trialCount;
cost = zeros(n, 1);
completed = false(n, 1);
aborted = false(n, 1);
semiAssemblyCount = zeros(n, 1);
finalAssemblyCount = zeros(n, 1);
marketReturns = zeros(n, 1);
semiDisassemblyCount = zeros(n, 1);
finalDisassemblyCount = zeros(n, 1);

partAvailable = false(n, 8);
partGoodInventory = false(n, 8);
semiAvailable = false(n, 3);
semiGoodInventory = false(n, 3);
semiPartInventory = false(n, 8);

for finalCycle = 1:options.MaxFinalCycles
    active = find(~completed & ~aborted);
    if isempty(active)
        break;
    end
    currentSemiGood = false(n, 3);
    currentSemiParts = false(n, 8);

    for semiIndex = 1:3
        group = scenario.componentGroups{semiIndex};
        fromInventory = active(semiAvailable(active, semiIndex));
        if ~isempty(fromInventory)
            currentSemiGood(fromInventory, semiIndex) = ...
                semiGoodInventory(fromInventory, semiIndex);
            currentSemiParts(fromInventory, group) = semiPartInventory(fromInventory, group);
            semiAvailable(fromInventory, semiIndex) = false;
        end

        pending = active(~semiAvailable(active, semiIndex) & ...
            ~ismember(active, fromInventory));
        for semiAttempt = 1:options.MaxSemiAttempts
            pending = pending(~aborted(pending));
            if isempty(pending)
                break;
            end
            partStates = false(numel(pending), numel(group));
            for localPart = 1:numel(group)
                partIndex = group(localPart);
                hasRecovered = partAvailable(pending, partIndex);
                partStates(hasRecovered, localPart) = ...
                    partGoodInventory(pending(hasRecovered), partIndex);
                needNewLocal = find(~hasRecovered);
                needNewGlobal = pending(needNewLocal);
                if ~isempty(needNewGlobal)
                    p = scenario.componentDefectRates(partIndex);
                    if strategy.inspectNew(partIndex)
                        drawCount = floor(log(rand(numel(needNewGlobal), 1)) ./ log(p)) + 1;
                        cost(needNewGlobal) = cost(needNewGlobal) + drawCount .* ...
                            (scenario.purchaseCosts(partIndex) + ...
                            scenario.componentInspectionCosts(partIndex));
                        partStates(needNewLocal, localPart) = true;
                    else
                        cost(needNewGlobal) = cost(needNewGlobal) + ...
                            scenario.purchaseCosts(partIndex);
                        partStates(needNewLocal, localPart) = ...
                            rand(numel(needNewGlobal), 1) >= p;
                    end
                end
                partAvailable(pending, partIndex) = false;
            end

            cost(pending) = cost(pending) + scenario.semiAssemblyCosts(semiIndex);
            semiAssemblyCount(pending) = semiAssemblyCount(pending) + 1;
            processGood = rand(numel(pending), 1) >= scenario.semiDefectRates(semiIndex);
            madeGood = all(partStates, 2) & processGood;

            if strategy.inspectSemi(semiIndex)
                cost(pending) = cost(pending) + scenario.semiInspectionCosts(semiIndex);
                passed = madeGood;
                passedGlobal = pending(passed);
                currentSemiGood(passedGlobal, semiIndex) = true;
                currentSemiParts(passedGlobal, group) = partStates(passed, :);
                failedGlobal = pending(~passed);
                failedParts = partStates(~passed, :);
                if strategy.disassembleSemi(semiIndex) && ~isempty(failedGlobal)
                    cost(failedGlobal) = cost(failedGlobal) + ...
                        scenario.semiDisassemblyCosts(semiIndex);
                    semiDisassemblyCount(failedGlobal) = ...
                        semiDisassemblyCount(failedGlobal) + 1;
                    recover_parts(failedGlobal, group, failedParts);
                end
                pending = failedGlobal;
            else
                currentSemiGood(pending, semiIndex) = madeGood;
                currentSemiParts(pending, group) = partStates;
                pending = zeros(0, 1);
            end
        end
        if ~isempty(pending)
            aborted(pending) = true;
        end
    end

    active = find(~completed & ~aborted);
    if isempty(active)
        continue;
    end
    semiAvailable(active, :) = false;
    cost(active) = cost(active) + scenario.finalAssemblyCost;
    finalAssemblyCount(active) = finalAssemblyCount(active) + 1;
    processGood = rand(numel(active), 1) >= scenario.finalDefectRate;
    finalGood = all(currentSemiGood(active, :), 2) & processGood;

    if strategy.inspectFinal
        cost(active) = cost(active) + scenario.finalInspectionCost;
        completed(active(finalGood)) = true;
        failedGlobal = active(~finalGood);
    else
        completed(active(finalGood)) = true;
        failedGlobal = active(~finalGood);
        cost(failedGlobal) = cost(failedGlobal) + scenario.exchangeLoss;
        marketReturns(failedGlobal) = marketReturns(failedGlobal) + 1;
    end

    if isempty(failedGlobal) || ~strategy.disassembleFinal
        continue;
    end
    cost(failedGlobal) = cost(failedGlobal) + scenario.finalDisassemblyCost;
    finalDisassemblyCount(failedGlobal) = finalDisassemblyCount(failedGlobal) + 1;

    for semiIndex = 1:3
        if ~strategy.reuseRecoveredSemis(semiIndex)
            continue;
        end
        group = scenario.componentGroups{semiIndex};
        semiStates = currentSemiGood(failedGlobal, semiIndex);
        partStates = currentSemiParts(failedGlobal, group);
        if strategy.inspectRecoveredSemis(semiIndex)
            cost(failedGlobal) = cost(failedGlobal) + ...
                scenario.semiInspectionCosts(semiIndex);
            goodGlobal = failedGlobal(semiStates);
            semiAvailable(goodGlobal, semiIndex) = true;
            semiGoodInventory(goodGlobal, semiIndex) = true;
            semiPartInventory(goodGlobal, group) = partStates(semiStates, :);
            badGlobal = failedGlobal(~semiStates);
            if strategy.disassembleSemi(semiIndex) && ~isempty(badGlobal)
                cost(badGlobal) = cost(badGlobal) + ...
                    scenario.semiDisassemblyCosts(semiIndex);
                semiDisassemblyCount(badGlobal) = semiDisassemblyCount(badGlobal) + 1;
                recover_parts(badGlobal, group, partStates(~semiStates, :));
            end
        else
            semiAvailable(failedGlobal, semiIndex) = true;
            semiGoodInventory(failedGlobal, semiIndex) = semiStates;
            semiPartInventory(failedGlobal, group) = partStates;
        end
    end
end

notCompleted = ~completed;
cost(notCompleted) = cost(notCompleted) + options.NoncompletionPenalty;
profit = scenario.salePrice - cost;
meanProfit = mean(profit);
profitStd = std(profit, 0);
standardError = profitStd / sqrt(n);
result.meanProfit = meanProfit;
result.profitStd = profitStd;
result.standardError = standardError;
result.ci95 = meanProfit + [-1, 1] .* 1.96 .* standardError;
result.completionRate = mean(completed);
result.meanSemiAssemblies = mean(semiAssemblyCount);
result.meanFinalAssemblies = mean(finalAssemblyCount);
result.meanMarketReturns = mean(marketReturns);
result.meanSemiDisassemblies = mean(semiDisassemblyCount);
result.meanFinalDisassemblies = mean(finalDisassemblyCount);

    function recover_parts(globalRows, componentIndices, states)
        for localIndex = 1:numel(componentIndices)
            componentIndex = componentIndices(localIndex);
            if ~strategy.reuseRecoveredParts(componentIndex)
                continue;
            end
            state = states(:, localIndex);
            if strategy.inspectRecoveredParts(componentIndex)
                cost(globalRows) = cost(globalRows) + ...
                    scenario.componentInspectionCosts(componentIndex);
                reusable = state;
            else
                reusable = true(numel(globalRows), 1);
            end
            target = globalRows(reusable);
            partAvailable(target, componentIndex) = true;
            partGoodInventory(target, componentIndex) = state(reusable);
        end
    end
end

