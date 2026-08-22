function outputs = run_problem3_experiment(config)
%RUN_PROBLEM3_EXPERIMENT 正式运行问题三GA、独立复评、基准和敏感性分析。

arguments
    config.PopulationSize (1,1) double {mustBeInteger, mustBePositive} = 80
    config.Generations (1,1) double {mustBeInteger, mustBePositive} = 100
    config.Trials (1,1) double {mustBeInteger, mustBeGreaterThan(config.Trials, 1)} = 1200
    config.Repeats (1,1) double {mustBeInteger, mustBePositive} = 6
    config.CandidateCount (1,1) double {mustBeInteger, mustBePositive} = 10
    config.ValidationTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.ValidationTrials, 1)} = 100000
    config.SensitivityPopulation (1,1) double {mustBeInteger, mustBePositive} = 60
    config.SensitivityGenerations (1,1) double {mustBeInteger, mustBePositive} = 60
    config.SensitivityTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.SensitivityTrials, 1)} = 800
    config.SensitivityRepeats (1,1) double {mustBeInteger, mustBePositive} = 3
    config.SensitivityValidationTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.SensitivityValidationTrials, 1)} = 40000
    config.Seed (1,1) double {mustBeInteger} = 202408
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root, 'results');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end
scenario = problem3_params();

[bestBits, bestSimulation, runs, histories, candidateTable] = optimize_and_validate( ...
    scenario, config.PopulationSize, config.Generations, config.Trials, ...
    config.Repeats, config.CandidateCount, config.ValidationTrials, config.Seed);
bestStrategy = decode_problem3_chromosome(bestBits);

benchmarkBits = create_benchmarks();
benchmarkNames = ["全部不检测不拆解"; "各层检测且拆解回用"; "分层质控直接回用"; "只检半成品和成品"];
benchmarkRows = struct([]);
for k = 1:size(benchmarkBits, 1)
    strategy = decode_problem3_chromosome(benchmarkBits(k, :));
    simulation = simulate_problem3_strategy(scenario, strategy, ...
        config.ValidationTrials, problem3_policy_seed(config.Seed + 700000, strategy.bits));
    benchmarkRows(k).name = benchmarkNames(k);
    benchmarkRows(k).chromosome = strategy.bitString;
    benchmarkRows(k).meanProfit = simulation.meanProfit;
    benchmarkRows(k).ci95Low = simulation.ci95(1);
    benchmarkRows(k).ci95High = simulation.ci95(2);
end
benchmarkTable = struct2table(benchmarkRows);
writetable(benchmarkTable, fullfile(resultDir, 'benchmark_comparison.csv'));

labels = ["defect_-20%", "defect_+20%", "exchange_-20%", "exchange_+20%"];
sensitivityRows = struct([]);
for k = 1:numel(labels)
    changed = perturb_problem3_scenario(scenario, labels(k));
    sensitivitySeed = config.Seed + 1000000 * k;
    [sensitiveBits, sensitiveSimulation] = optimize_and_validate( ...
        changed, config.SensitivityPopulation, config.SensitivityGenerations, ...
        config.SensitivityTrials, config.SensitivityRepeats, ...
        config.CandidateCount, config.SensitivityValidationTrials, sensitivitySeed);
    sensitiveStrategy = decode_problem3_chromosome(sensitiveBits);
    sensitivityRows(k).perturbation = labels(k);
    sensitivityRows(k).chromosome = sensitiveStrategy.bitString;
    sensitivityRows(k).meanProfit = sensitiveSimulation.meanProfit;
    sensitivityRows(k).sameAsBase = all(sensitiveBits == bestBits);
    fprintf('敏感性 %s：收益 %.4f。\n', labels(k), sensitiveSimulation.meanProfit);
end
sensitivityTable = struct2table(sensitivityRows);
writetable(sensitivityTable, fullfile(resultDir, 'sensitivity.csv'));

writetable(runs, fullfile(resultDir, 'ga_runs.csv'));
writetable(candidateTable, fullfile(resultDir, 'validated_candidates.csv'));
summaryTable = make_summary_table(bestStrategy, bestSimulation, runs, config);
writetable(summaryTable, fullfile(resultDir, 'optimal_strategy.csv'));

figure('Visible', 'off', 'Color', 'w');
plot(1:config.Generations, histories, 'LineWidth', 1.25);
xlabel('迭代代数'); ylabel('当代最优平均净收益');
legend(compose('独立运行%d', 1:config.Repeats), 'Location', 'southeast');
grid on;
exportgraphics(gcf, fullfile(resultDir, 'ga_convergence.png'), 'Resolution', 180);
close(gcf);

write_problem3_report(fullfile(resultDir, 'experiment_report.md'), ...
    bestStrategy, bestSimulation, runs, benchmarkTable, sensitivityTable, config);
save(fullfile(resultDir, 'workspace_results.mat'), 'config', 'scenario', ...
    'bestStrategy', 'bestSimulation', 'runs', 'candidateTable', ...
    'benchmarkTable', 'sensitivityTable', 'histories');
outputs = struct('bestStrategy', bestStrategy, 'bestSimulation', bestSimulation, ...
    'runs', runs, 'candidates', candidateTable, 'benchmarks', benchmarkTable, ...
    'sensitivity', sensitivityTable, 'histories', histories);
fprintf('问题三完成：%s，平均净收益 %.4f。\n', ...
    bestStrategy.bitString, bestSimulation.meanProfit);
end


function [bestBits, bestSimulation, runs, histories, candidateTable] = ...
    optimize_and_validate(scenario, populationSize, generations, trials, ...
    repeats, candidateCount, validationTrials, seed)

allCandidates = zeros(0, 38);
histories = zeros(generations, repeats);
runIndex = (1:repeats)';
runChromosome = strings(repeats, 1);
searchFitness = zeros(repeats, 1);
uniqueEvaluations = zeros(repeats, 1);
for repeat = 1:repeats
    evaluationSeed = seed + repeat * 10000;
    gaConfig = struct( ...
        'PopulationSize', populationSize, ...
        'Generations', generations, ...
        'CrossoverProbability', 0.8, ...
        'MutationProbability', 0.03, ...
        'TournamentSize', 3, ...
        'EliteCount', 2, ...
        'Trials', trials, ...
        'EvaluationSeed', evaluationSeed, ...
        'CandidateCount', candidateCount);
    ga = run_problem3_ga(scenario, gaConfig, evaluationSeed + 17);
    allCandidates = [allCandidates; ga.candidateBits]; %#ok<AGROW>
    histories(:, repeat) = ga.history;
    runChromosome(repeat) = decode_problem3_chromosome(ga.bestBits).bitString;
    searchFitness(repeat) = ga.bestFitness;
    uniqueEvaluations(repeat) = ga.uniqueEvaluations;
    fprintf('GA运行%d/%d：搜索收益 %.4f，评价策略 %d 个。\n', ...
        repeat, repeats, ga.bestFitness, ga.uniqueEvaluations);
end

benchmarks = create_benchmarks();
allCandidates = unique([allCandidates; benchmarks], 'rows', 'stable');
validatedProfit = zeros(size(allCandidates, 1), 1);
ciLow = zeros(size(allCandidates, 1), 1);
ciHigh = zeros(size(allCandidates, 1), 1);
completionRate = zeros(size(allCandidates, 1), 1);
simulations = cell(size(allCandidates, 1), 1);
for row = 1:size(allCandidates, 1)
    strategy = decode_problem3_chromosome(allCandidates(row, :));
    simulations{row} = simulate_problem3_strategy(scenario, strategy, ...
        validationTrials, problem3_policy_seed(seed + 500000, strategy.bits));
    validatedProfit(row) = simulations{row}.meanProfit;
    ciLow(row) = simulations{row}.ci95(1);
    ciHigh(row) = simulations{row}.ci95(2);
    completionRate(row) = simulations{row}.completionRate;
end
[~, order] = sort(validatedProfit, 'descend');
allCandidates = allCandidates(order, :);
validatedProfit = validatedProfit(order);
ciLow = ciLow(order); ciHigh = ciHigh(order); completionRate = completionRate(order);
simulations = simulations(order);
bestBits = allCandidates(1, :);
bestSimulation = simulations{1};

candidateChromosome = strings(size(allCandidates, 1), 1);
for row = 1:size(allCandidates, 1)
    candidateChromosome(row) = decode_problem3_chromosome(allCandidates(row, :)).bitString;
end
candidateTable = table(candidateChromosome, validatedProfit, ciLow, ciHigh, completionRate, ...
    'VariableNames', {'Chromosome','MeanProfit','CI95Low','CI95High','CompletionRate'});
runs = table(runIndex, runChromosome, searchFitness, uniqueEvaluations, ...
    'VariableNames', {'Run','SearchChromosome','SearchFitness','UniqueEvaluations'});
end


function rows = create_benchmarks()
rows = zeros(4, 38);
rows(1, :) = decode_problem3_chromosome(zeros(1, 38)).bits;
rows(2, :) = decode_problem3_chromosome(ones(1, 38)).bits;
rows(3, :) = decode_problem3_chromosome([ones(1,8), ones(1,3), 0, ...
    ones(1,3), 1, zeros(1,8), ones(1,8), zeros(1,3), ones(1,3)]).bits;
rows(4, :) = decode_problem3_chromosome([zeros(1,8), ones(1,3), 1, ...
    ones(1,3), 1, ones(1,8), ones(1,8), ones(1,3), ones(1,3)]).bits;
end


function changed = perturb_problem3_scenario(scenario, label)
changed = scenario;
switch label
    case "defect_-20%"
        changed.componentDefectRates = 0.8 * scenario.componentDefectRates;
        changed.semiDefectRates = 0.8 * scenario.semiDefectRates;
        changed.finalDefectRate = 0.8 * scenario.finalDefectRate;
    case "defect_+20%"
        changed.componentDefectRates = 1.2 * scenario.componentDefectRates;
        changed.semiDefectRates = 1.2 * scenario.semiDefectRates;
        changed.finalDefectRate = 1.2 * scenario.finalDefectRate;
    case "exchange_-20%"
        changed.exchangeLoss = 0.8 * scenario.exchangeLoss;
    case "exchange_+20%"
        changed.exchangeLoss = 1.2 * scenario.exchangeLoss;
    otherwise
        error('未知扰动：%s', label);
end
end


function output = make_summary_table(strategy, simulation, runs, config)
Chromosome = string(strategy.bitString);
Description = string(problem3_strategy_description(strategy));
MeanProfit = simulation.meanProfit;
CI95Low = simulation.ci95(1); CI95High = simulation.ci95(2);
CompletionRate = simulation.completionRate;
MeanSemiAssemblies = simulation.meanSemiAssemblies;
MeanFinalAssemblies = simulation.meanFinalAssemblies;
MeanMarketReturns = simulation.meanMarketReturns;
MeanSemiDisassemblies = simulation.meanSemiDisassemblies;
MeanFinalDisassemblies = simulation.meanFinalDisassemblies;
ExactSearchWinnerCount = sum(runs.SearchChromosome == Chromosome);
IndependentRuns = config.Repeats;
output = table(Chromosome, Description, MeanProfit, CI95Low, CI95High, ...
    CompletionRate, MeanSemiAssemblies, MeanFinalAssemblies, MeanMarketReturns, ...
    MeanSemiDisassemblies, MeanFinalDisassemblies, ExactSearchWinnerCount, IndependentRuns);
end


function write_problem3_report(path, strategy, simulation, runs, benchmarks, sensitivity, config)
fid = fopen(path, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# 问题三分层随机闭环—蒙特卡洛—遗传算法实验结果\n\n');
fprintf(fid, '## 染色体\n\n');
fprintf(fid, '`X(8)|H(3)|Y|D(3)|Z|R(8)|U(8)|S(3)|V(3)`，共38位。\n\n');
fprintf(fid, '## 正式结果\n\n');
fprintf(fid, '- 最优染色体：`%s`\n', strategy.bitString);
fprintf(fid, '- 决策：%s\n', problem3_strategy_description(strategy));
fprintf(fid, '- 平均净收益：%.4f 元/次合格交付\n', simulation.meanProfit);
fprintf(fid, '- 95%%蒙特卡洛区间：[%.4f, %.4f]\n', simulation.ci95(1), simulation.ci95(2));
fprintf(fid, '- 闭环完成率：%.6f\n', simulation.completionRate);
fprintf(fid, '- 平均半成品装配次数：%.4f；平均成品装配次数：%.4f\n', ...
    simulation.meanSemiAssemblies, simulation.meanFinalAssemblies);
fprintf(fid, '- 平均市场退回次数：%.4f；平均半成品拆解次数：%.4f；平均成品拆解次数：%.4f\n\n', ...
    simulation.meanMarketReturns, simulation.meanSemiDisassemblies, ...
    simulation.meanFinalDisassemblies);
fprintf(fid, '## 实验参数与验证\n\n');
fprintf(fid, '- 基准GA：种群%d、%d代、适应度样本%d、独立运行%d次。\n', ...
    config.PopulationSize, config.Generations, config.Trials, config.Repeats);
fprintf(fid, '- 交叉概率0.8、变异概率0.03、锦标赛规模3、精英数2。\n');
fprintf(fid, '- 每次GA保留%d个候选，合并去重后用%d次独立仿真统一复评。\n', ...
    config.CandidateCount, config.ValidationTrials);
fprintf(fid, '- 搜索空间为2^38，不能全枚举；结果是多次启发式搜索下发现的最优策略，不宣称数学上的全局最优。\n\n');
fprintf(fid, '## 独立运行\n\n');
fprintf(fid, '|运行|搜索最优染色体|搜索适应度|评价策略数|\n|---:|:---|---:|---:|\n');
for i = 1:height(runs)
    fprintf(fid, '|%d|`%s`|%.4f|%d|\n', runs.Run(i), char(string(runs.SearchChromosome(i))), ...
        runs.SearchFitness(i), runs.UniqueEvaluations(i));
end
fprintf(fid, '\n## 基准对比\n\n');
fprintf(fid, '|基准|平均净收益|95%%区间|\n|:---|---:|:---:|\n');
for i = 1:height(benchmarks)
    fprintf(fid, '|%s|%.4f|[%.4f, %.4f]|\n', char(string(benchmarks.name(i))), ...
        benchmarks.meanProfit(i), benchmarks.ci95Low(i), benchmarks.ci95High(i));
end
fprintf(fid, '\n## 敏感性\n\n');
fprintf(fid, '|扰动|重新优化染色体|平均净收益|与基准相同|\n|:---|:---|---:|:---:|\n');
for i = 1:height(sensitivity)
    fprintf(fid, '|%s|`%s`|%.4f|%d|\n', ...
        char(string(sensitivity.perturbation(i))), ...
        char(string(sensitivity.chromosome(i))), ...
        sensitivity.meanProfit(i), sensitivity.sameAsBase(i));
end
end
