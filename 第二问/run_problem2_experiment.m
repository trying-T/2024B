function outputs = run_problem2_experiment(config)
%RUN_PROBLEM2_EXPERIMENT 运行六种情形的GA、枚举校验与敏感性分析。

arguments
    config.PopulationSize (1,1) double {mustBeInteger, mustBePositive} = 100
    config.Generations (1,1) double {mustBeInteger, mustBePositive} = 200
    config.Trials (1,1) double {mustBeInteger, mustBeGreaterThan(config.Trials, 1)} = 5000
    config.Repeats (1,1) double {mustBeInteger, mustBePositive} = 10
    config.ValidationTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.ValidationTrials, 1)} = 100000
    config.SensitivityTrials (1,1) double {mustBeInteger, mustBeGreaterThan(config.SensitivityTrials, 1)} = 30000
    config.Seed (1,1) double {mustBeInteger} = 202408
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root, 'results');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end
scenarios = problem2_params();
allStrategies = enumerate_strategies(2);
assert(size(allStrategies, 1) == 80, '有效策略数应为80。');

gaScenario = []; gaRepeat = []; gaChromosome = strings(0,1);
gaFitness = []; gaUniqueEvaluations = [];
summary = struct([]);
sensitivity = struct([]);
histories = zeros(config.Generations, numel(scenarios));
sensIndex = 0;

for s = 1:numel(scenarios)
    scenario = scenarios(s);
    winnerBits = zeros(config.Repeats, size(allStrategies, 2));
    for repeat = 1:config.Repeats
        evaluationSeed = config.Seed + scenario.id * 100000 + (repeat - 1) * 1000;
        gaConfig = struct( ...
            'PopulationSize', config.PopulationSize, ...
            'Generations', config.Generations, ...
            'CrossoverProbability', 0.8, ...
            'MutationProbability', 0.03, ...
            'TournamentSize', 3, ...
            'EliteCount', 2, ...
            'Trials', config.Trials, ...
            'EvaluationSeed', evaluationSeed);
        ga = run_genetic_algorithm(scenario, gaConfig, evaluationSeed + 17);
        winnerBits(repeat, :) = ga.bestBits;
        if repeat == 1
            histories(:, s) = ga.history;
        end
        gaScenario(end + 1, 1) = scenario.id; %#ok<AGROW>
        gaRepeat(end + 1, 1) = repeat; %#ok<AGROW>
        gaChromosome(end + 1, 1) = decode_chromosome(ga.bestBits, 2).bitString; %#ok<AGROW>
        gaFitness(end + 1, 1) = ga.bestFitness; %#ok<AGROW>
        gaUniqueEvaluations(end + 1, 1) = ga.uniqueEvaluations; %#ok<AGROW>
    end

    validationSeed = config.Seed + scenario.id * 1000000 + 777;
    validationFitness = zeros(size(allStrategies, 1), 1);
    validationResults = cell(size(allStrategies, 1), 1);
    for k = 1:size(allStrategies, 1)
        strategy = decode_chromosome(allStrategies(k, :), 2);
        policyCode = sum(strategy.bits .* 2 .^ (0:7));
        validationResults{k} = simulate_strategy(scenario, strategy, ...
            config.ValidationTrials, validationSeed + 1000003 * policyCode);
        validationFitness(k) = validationResults{k}.meanProfit;
    end
    [~, bestIndex] = max(validationFitness);
    bestBits = allStrategies(bestIndex, :);
    bestStrategy = decode_chromosome(bestBits, 2);
    bestResult = validationResults{bestIndex};
    hitCount = sum(all(winnerBits == bestBits, 2));

    summary(s).scenario = scenario.id;
    summary(s).chromosome = bestStrategy.bitString;
    summary(s).bits = bestBits;
    summary(s).description = strategy_description(bestStrategy);
    summary(s).simulation = bestResult;
    summary(s).gaHitCount = hitCount;
    summary(s).gaHitRate = hitCount / config.Repeats;

    labels = ["defect_-20%", "defect_+20%", "exchange_-20%", "exchange_+20%"];
    for label = labels
        changed = perturb_scenario(scenario, label);
        values = zeros(size(allStrategies, 1), 1);
        for k = 1:size(allStrategies, 1)
            strategy = decode_chromosome(allStrategies(k, :), 2);
            policyCode = sum(strategy.bits .* 2 .^ (0:7));
            labelCode = sum(double(char(label)));
            sim = simulate_strategy(changed, strategy, config.SensitivityTrials, ...
                validationSeed + 101 * labelCode + 1000003 * policyCode);
            values(k) = sim.meanProfit;
        end
        [bestValue, index] = max(values);
        sensIndex = sensIndex + 1;
        sensitivity(sensIndex).scenario = scenario.id;
        sensitivity(sensIndex).perturbation = label;
        sensitivity(sensIndex).chromosome = decode_chromosome(allStrategies(index, :), 2).bitString;
        sensitivity(sensIndex).meanProfit = bestValue;
        sensitivity(sensIndex).sameAsBase = all(allStrategies(index, :) == bestBits);
    end
    fprintf('情形%d完成：%s，平均净收益 %.4f，GA命中 %d/%d。\n', ...
        scenario.id, bestStrategy.bitString, bestResult.meanProfit, hitCount, config.Repeats);
end

gaTable = table(gaScenario, gaRepeat, gaChromosome, gaFitness, gaUniqueEvaluations, ...
    'VariableNames', {'Scenario','Repeat','Chromosome','Fitness','UniqueEvaluations'});
writetable(gaTable, fullfile(resultDir, 'ga_runs.csv'));

summaryTable = summary_to_table(summary);
writetable(summaryTable, fullfile(resultDir, 'optimal_strategies.csv'));
sensitivityTable = struct2table(sensitivity);
writetable(sensitivityTable, fullfile(resultDir, 'sensitivity.csv'));

figure('Visible', 'off', 'Color', 'w');
plot(1:config.Generations, histories, 'LineWidth', 1.4);
xlabel('迭代代数'); ylabel('当代最优平均净收益');
legend(compose('情形%d', 1:numel(scenarios)), 'Location', 'southeast');
grid on;
exportgraphics(gcf, fullfile(resultDir, 'ga_convergence.png'), 'Resolution', 180);
close(gcf);

write_report(fullfile(resultDir, 'experiment_report.md'), summary, config);
save(fullfile(resultDir, 'workspace_results.mat'), 'config', 'scenarios', ...
    'summary', 'sensitivity', 'histories', 'gaTable');
outputs = struct('summary', summary, 'sensitivity', sensitivity, ...
    'histories', histories, 'gaRuns', gaTable);
end


function changed = perturb_scenario(scenario, label)
changed = scenario;
switch label
    case "defect_-20%"
        changed.componentDefectRates = 0.8 * scenario.componentDefectRates;
        changed.finalDefectRate = 0.8 * scenario.finalDefectRate;
    case "defect_+20%"
        changed.componentDefectRates = min(0.999, 1.2 * scenario.componentDefectRates);
        changed.finalDefectRate = min(0.999, 1.2 * scenario.finalDefectRate);
    case "exchange_-20%"
        changed.exchangeLoss = 0.8 * scenario.exchangeLoss;
    case "exchange_+20%"
        changed.exchangeLoss = 1.2 * scenario.exchangeLoss;
    otherwise
        error('未知扰动：%s', label);
end
end


function output = summary_to_table(summary)
n = numel(summary);
Scenario = zeros(n,1); Chromosome = strings(n,1); Description = strings(n,1);
MeanProfit = zeros(n,1); CI95Low = zeros(n,1); CI95High = zeros(n,1);
CompletionRate = zeros(n,1); MeanAssemblies = zeros(n,1);
MeanMarketReturns = zeros(n,1); MeanDisassemblies = zeros(n,1);
GAHitRate = zeros(n,1);
for i = 1:n
    Scenario(i) = summary(i).scenario;
    Chromosome(i) = summary(i).chromosome;
    Description(i) = summary(i).description;
    sim = summary(i).simulation;
    MeanProfit(i) = sim.meanProfit; CI95Low(i) = sim.ci95(1); CI95High(i) = sim.ci95(2);
    CompletionRate(i) = sim.completionRate; MeanAssemblies(i) = sim.meanAssemblies;
    MeanMarketReturns(i) = sim.meanMarketReturns; MeanDisassemblies(i) = sim.meanDisassemblies;
    GAHitRate(i) = summary(i).gaHitRate;
end
output = table(Scenario, Chromosome, Description, MeanProfit, CI95Low, CI95High, ...
    CompletionRate, MeanAssemblies, MeanMarketReturns, MeanDisassemblies, GAHitRate);
end


function write_report(path, summary, config)
fid = fopen(path, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# 问题二随机闭环—蒙特卡洛—遗传算法实验结果\n\n');
fprintf(fid, '染色体格式为 `x1x2|yz|r1r2|u1u2`。适应度是完成一件最终合格交付后的平均净收益。\n\n');
fprintf(fid, '参数：种群 %d，迭代 %d，交叉 0.8，变异 0.03，适应度样本 %d，独立重复 %d，最终复评 %d，随机种子 %d。\n\n', ...
    config.PopulationSize, config.Generations, config.Trials, config.Repeats, ...
    config.ValidationTrials, config.Seed);
fprintf(fid, '| 情形 | 最优染色体 | 平均净收益 | 95%% MC区间 | GA命中 | 决策 |\n');
fprintf(fid, '|---:|:---:|---:|:---:|:---:|:---|\n');
for i = 1:numel(summary)
    sim = summary(i).simulation;
    fprintf(fid, '| %d | `%s` | %.4f | [%.4f, %.4f] | %d/%d | %s |\n', ...
        summary(i).scenario, summary(i).chromosome, sim.meanProfit, ...
        sim.ci95(1), sim.ci95(2), summary(i).gaHitCount, config.Repeats, ...
        summary(i).description);
end
fprintf(fid, '\n两零件原始空间有256个二进制串，修复无效位后有80个语义不同的策略。最终结果来自独立大样本全枚举复评；GA命中率用于验证启发式搜索稳定性。敏感性分析对次品率和调换损失分别上下扰动20%%并完整重算。\n');
end

