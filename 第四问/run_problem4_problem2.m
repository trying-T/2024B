function outputs = run_problem4_problem2(config)
%RUN_PROBLEM4_PROBLEM2 问题四中对问题二的联合区间稳健全枚举实验。

arguments
    config.ValidationTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.ValidationTrials, 1)} = 100000
    config.ScenarioTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.ScenarioTrials, 1)} = 30000
    config.LHSCount (1,1) double {mustBeInteger, mustBePositive} = 64
    config.Seed (1,1) double {mustBeInteger} = 202409
end

root = problem4_setup_paths();
resultDir = fullfile(root, 'results_problem2');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

baseScenarios = problem2_params();
allStrategies = enumerate_strategies(2);
assert(size(allStrategies, 1) == 80, '问题二有效策略数必须为80。');

intervalRows = struct([]);
summaryRows = struct([]);
validationRows = struct([]);
intervalIndex = 0;
validationIndex = 0;

for caseIndex = 1:numel(baseScenarios)
    baseScenario = baseScenarios(caseIndex);
    nominal = [baseScenario.componentDefectRates, baseScenario.finalDefectRate];
    sampling = problem4_sampling_intervals(nominal, 3);
    parameterNames = ["零配件1", "零配件2", "成品工序"];
    for j = 1:3
        intervalIndex = intervalIndex + 1;
        intervalRows(intervalIndex).Case = baseScenario.id;
        intervalRows(intervalIndex).Parameter = parameterNames(j);
        intervalRows(intervalIndex).NominalRate = nominal(j);
        intervalRows(intervalIndex).RejectSampleSize = sampling.nReject(j);
        intervalRows(intervalIndex).AcceptSampleSize = sampling.nAccept(j);
        intervalRows(intervalIndex).SampleSize = sampling.sampleSize(j);
        intervalRows(intervalIndex).DefectCount = sampling.defectCount(j);
        intervalRows(intervalIndex).AlphaPerParameter = sampling.alphaPerParameter;
        intervalRows(intervalIndex).LowerBound = sampling.lower(j);
        intervalRows(intervalIndex).UpperBound = sampling.upper(j);
    end

    centerScenario = problem4_set_problem2_rates(baseScenario, nominal);
    upperScenario = problem4_set_problem2_rates(baseScenario, sampling.upper);
    [centerValues, centerResults] = evaluate_all(centerScenario, allStrategies, ...
        config.ValidationTrials, config.Seed + baseScenario.id * 1000000);
    [upperValues, upperResults] = evaluate_all(upperScenario, allStrategies, ...
        config.ValidationTrials, config.Seed + baseScenario.id * 2000000);

    [~, pointIndex] = max(centerValues);
    [~, robustIndex] = max(upperValues);
    pointStrategy = decode_chromosome(allStrategies(pointIndex, :), 2);
    robustStrategy = decode_chromosome(allStrategies(robustIndex, :), 2);

    summaryRows(caseIndex).Case = baseScenario.id;
    summaryRows(caseIndex).PointChromosome = string(pointStrategy.bitString);
    summaryRows(caseIndex).RobustChromosome = string(robustStrategy.bitString);
    summaryRows(caseIndex).PointDescription = string(strategy_description(pointStrategy));
    summaryRows(caseIndex).RobustDescription = string(strategy_description(robustStrategy));
    summaryRows(caseIndex).PointCenterProfit = centerResults{pointIndex}.meanProfit;
    summaryRows(caseIndex).RobustCenterProfit = centerResults{robustIndex}.meanProfit;
    summaryRows(caseIndex).PointUpperProfit = upperResults{pointIndex}.meanProfit;
    summaryRows(caseIndex).RobustUpperProfit = upperResults{robustIndex}.meanProfit;
    summaryRows(caseIndex).RobustUpperCI95Low = upperResults{robustIndex}.ci95(1);
    summaryRows(caseIndex).RobustUpperCI95High = upperResults{robustIndex}.ci95(2);
    summaryRows(caseIndex).RobustnessCost = ...
        centerResults{pointIndex}.meanProfit - centerResults{robustIndex}.meanProfit;
    summaryRows(caseIndex).WorstCaseGain = ...
        upperResults{robustIndex}.meanProfit - upperResults{pointIndex}.meanProfit;
    summaryRows(caseIndex).SameStrategy = pointIndex == robustIndex;

    [rates, labels] = validation_scenarios(sampling, config.LHSCount, ...
        config.Seed + baseScenario.id * 3000000);
    selectedBits = [allStrategies(pointIndex, :); allStrategies(robustIndex, :)];
    selectedNames = ["点估计策略"; "稳健策略"];
    for policyIndex = 1:2
        policy = decode_chromosome(selectedBits(policyIndex, :), 2);
        for scenarioIndex = 1:size(rates, 1)
            changed = problem4_set_problem2_rates(baseScenario, rates(scenarioIndex, :));
            policyCode = sum(policy.bits .* 2 .^ (0:7));
            simulation = simulate_strategy(changed, policy, config.ScenarioTrials, ...
                config.Seed + baseScenario.id * 10000000 + ...
                policyIndex * 1000000 + scenarioIndex * 1000 + policyCode);
            validationIndex = validationIndex + 1;
            validationRows(validationIndex).Case = baseScenario.id;
            validationRows(validationIndex).PolicyType = selectedNames(policyIndex);
            validationRows(validationIndex).Chromosome = string(policy.bitString);
            validationRows(validationIndex).Scenario = labels(scenarioIndex);
            validationRows(validationIndex).Part1Rate = rates(scenarioIndex, 1);
            validationRows(validationIndex).Part2Rate = rates(scenarioIndex, 2);
            validationRows(validationIndex).FinalRate = rates(scenarioIndex, 3);
            validationRows(validationIndex).MeanProfit = simulation.meanProfit;
            validationRows(validationIndex).CI95Low = simulation.ci95(1);
            validationRows(validationIndex).CI95High = simulation.ci95(2);
            validationRows(validationIndex).CompletionRate = simulation.completionRate;
        end
    end
    fprintf('问题四-问题二情形%d：点估计%s，稳健%s，最坏利润%.4f。\n', ...
        baseScenario.id, pointStrategy.bitString, robustStrategy.bitString, ...
        upperResults{robustIndex}.meanProfit);
end

intervalTable = struct2table(intervalRows);
summaryTable = struct2table(summaryRows);
validationTable = struct2table(validationRows);
writetable(intervalTable, fullfile(resultDir, 'sampling_intervals.csv'));
writetable(summaryTable, fullfile(resultDir, 'strategy_comparison.csv'));
writetable(validationTable, fullfile(resultDir, 'scenario_validation.csv'));

draw_profit_comparison(summaryTable, fullfile(resultDir, 'profit_comparison.png'));
write_report(fullfile(resultDir, 'experiment_report.md'), summaryTable, ...
    intervalTable, config);
save(fullfile(resultDir, 'workspace_results.mat'), 'config', 'baseScenarios', ...
    'intervalTable', 'summaryTable', 'validationTable');

outputs = struct('intervals', intervalTable, 'summary', summaryTable, ...
    'validation', validationTable);
end


function [values, results] = evaluate_all(scenario, strategies, trials, baseSeed)
count = size(strategies, 1);
values = zeros(count, 1);
results = cell(count, 1);
for row = 1:count
    strategy = decode_chromosome(strategies(row, :), 2);
    policyCode = sum(strategy.bits .* 2 .^ (0:7));
    results{row} = simulate_strategy(scenario, strategy, trials, ...
        baseSeed + 1000003 * policyCode);
    values(row) = results{row}.meanProfit;
end
end


function [rates, labels] = validation_scenarios(sampling, lhsCount, seed)
dimension = sampling.familySize;
rates = [sampling.nominalRates; sampling.lower; sampling.upper];
labels = ["中心"; "联合下界"; "联合上界"];
for j = 1:dimension
    lowRow = sampling.nominalRates;
    highRow = sampling.nominalRates;
    lowRow(j) = sampling.lower(j);
    highRow(j) = sampling.upper(j);
    rates = [rates; lowRow; highRow]; %#ok<AGROW>
    labels = [labels; "参数" + j + "下界"; "参数" + j + "上界"]; %#ok<AGROW>
end
lhs = problem4_lhs(sampling.lower, sampling.upper, lhsCount, seed);
rates = [rates; lhs];
labels = [labels; "LHS" + string((1:lhsCount)')];
end


function draw_profit_comparison(data, outputFile)
figure('Visible', 'off', 'Color', 'w');
values = [data.PointCenterProfit, data.RobustCenterProfit, ...
    data.PointUpperProfit, data.RobustUpperProfit];
bar(data.Case, values, 'grouped');
xlabel('问题二情形');
ylabel('平均净收益');
legend({'表中次品率策略-表中值', '上界情景策略-表中值', ...
    '表中次品率策略-联合上界', '上界情景策略-联合上界'}, ...
    'Location', 'bestoutside');
grid on;
exportgraphics(gcf, outputFile, 'Resolution', 180);
close(gcf);
end


function write_report(path, summary, intervals, config)
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid >= 0, '无法写入问题二实验报告。');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# 问题四：问题二联合置信区间稳健实验\n\n');
fprintf(fid, ['表中次品率作为样本估计；样本量取问题一接收、拒收推荐值较大者；', ...
    '次品数按 `round(n*p)` 反推；每种情形对3个参数进行Bonferroni修正。\n\n']);
fprintf(fid, '全枚举80种有效策略；中心和联合上界复评次数均为%d，验证情景每次%d，LHS情景%d个。\n\n', ...
    config.ValidationTrials, config.ScenarioTrials, config.LHSCount);
fprintf(fid, '|情形|点估计策略|稳健策略|点估计中心利润|稳健中心利润|点估计上界利润|稳健上界利润|稳健代价|最坏改善|\n');
fprintf(fid, '|---:|:---:|:---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary)
    fprintf(fid, '|%d|`%s`|`%s`|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|\n', ...
        summary.Case(i), char(summary.PointChromosome(i)), ...
        char(summary.RobustChromosome(i)), summary.PointCenterProfit(i), ...
        summary.RobustCenterProfit(i), summary.PointUpperProfit(i), ...
        summary.RobustUpperProfit(i), summary.RobustnessCost(i), ...
        summary.WorstCaseGain(i));
end
fprintf(fid, '\n## 抽样区间\n\n');
fprintf(fid, '|情形|参数|样本估计|n|x|下界|上界|\n|---:|:---|---:|---:|---:|---:|---:|\n');
for i = 1:height(intervals)
    fprintf(fid, '|%d|%s|%.4f|%d|%d|%.6f|%.6f|\n', ...
        intervals.Case(i), char(intervals.Parameter(i)), ...
        intervals.NominalRate(i), intervals.SampleSize(i), ...
        intervals.DefectCount(i), intervals.LowerBound(i), ...
        intervals.UpperBound(i));
end
end
