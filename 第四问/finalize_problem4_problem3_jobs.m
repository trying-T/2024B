function outputs = finalize_problem4_problem3_jobs()
%FINALIZE_PROBLEM4_PROBLEM3_JOBS 汇总6个正式GA检查点并完成既定复评。

root = problem4_setup_paths();
resultDir = fullfile(root, 'results_problem3');
jobDir = fullfile(resultDir, 'jobs');
baseSeed = 202409;
validationTrials = 300000;
scenarioTrials = 20000;
lhsCount = 128;

baseScenario = problem3_params();
nominal = [baseScenario.componentDefectRates, ...
    baseScenario.semiDefectRates, baseScenario.finalDefectRate];
sampling = problem4_sampling_intervals(nominal, 12);
upperScenario = problem4_set_problem3_rates(baseScenario, sampling.upper);
intervalTable = make_interval_table(sampling);

allCandidates = zeros(0, 38);
histories = zeros(100, 6);
Run = (1:6)';
SearchChromosome = strings(6, 1);
SearchFitness = zeros(6, 1);
UniqueEvaluations = zeros(6, 1);
for i = 1:6
    path = fullfile(jobDir, sprintf('upper_%02d.mat', i));
    assert(isfile(path), '缺少正式GA检查点：%s', path);
    loaded = load(path, 'ga');
    ga = loaded.ga;
    allCandidates = [allCandidates; ga.candidateBits]; %#ok<AGROW>
    histories(:, i) = ga.history;
    SearchChromosome(i) = decode_problem3_chromosome(ga.bestBits).bitString;
    SearchFitness(i) = ga.bestFitness;
    UniqueEvaluations(i) = ga.uniqueEvaluations;
end
runs = table(Run, SearchChromosome, SearchFitness, UniqueEvaluations);

pointBits = decode_problem3_chromosome([ones(1,8), ones(1,3), 0, ...
    ones(1,3), 1, zeros(1,8), ones(1,8), zeros(1,3), ones(1,3)]).bits;
allCandidates = unique([allCandidates; pointBits], 'rows', 'stable');
[candidateTable, simulations, orderedBits] = validate_candidates( ...
    upperScenario, allCandidates, validationTrials, baseSeed + 500000);
robustBits = orderedBits(1, :);
robustStrategy = decode_problem3_chromosome(robustBits);
robustUpper = simulations{1};
pointStrategy = decode_problem3_chromosome(pointBits);

pointCenter = simulate_problem3_strategy(baseScenario, pointStrategy, ...
    validationTrials, problem3_policy_seed(baseSeed + 600000, pointBits));
robustCenter = simulate_problem3_strategy(baseScenario, robustStrategy, ...
    validationTrials, problem3_policy_seed(baseSeed + 700000, robustBits));
pointUpper = simulate_problem3_strategy(upperScenario, pointStrategy, ...
    validationTrials, problem3_policy_seed(baseSeed + 800000, pointBits));
summaryTable = make_summary(pointStrategy, robustStrategy, pointCenter, ...
    robustCenter, pointUpper, robustUpper);

[rates, labels] = validation_scenarios(sampling, lhsCount, baseSeed + 900000);
validationTable = evaluate_validation_scenarios(baseScenario, rates, labels, ...
    pointStrategy, robustStrategy, scenarioTrials, baseSeed + 1000000);

writetable(intervalTable, fullfile(resultDir, 'sampling_intervals.csv'));
writetable(summaryTable, fullfile(resultDir, 'strategy_comparison.csv'));
writetable(candidateTable, fullfile(resultDir, 'validated_candidates.csv'));
writetable(runs, fullfile(resultDir, 'ga_runs.csv'));
writetable(validationTable, fullfile(resultDir, 'scenario_validation.csv'));
draw_convergence(histories, fullfile(resultDir, 'ga_convergence.png'));
write_report(fullfile(resultDir, 'experiment_report.md'), summaryTable, ...
    intervalTable, runs, robustStrategy, validationTrials, scenarioTrials, lhsCount);
save(fullfile(resultDir, 'workspace_results.mat'), 'baseScenario', ...
    'upperScenario', 'sampling', 'intervalTable', 'summaryTable', 'runs', ...
    'candidateTable', 'validationTable', 'histories', 'pointStrategy', ...
    'robustStrategy');

outputs = struct('intervals', intervalTable, 'summary', summaryTable, ...
    'runs', runs, 'candidates', candidateTable, 'validation', validationTable, ...
    'histories', histories);
fprintf('问题四-问题三汇总完成：稳健策略%s，联合上界利润%.4f。\n', ...
    robustStrategy.bitString, robustUpper.meanProfit);
end


function tableOut = make_interval_table(sampling)
Parameter = ["零配件" + string((1:8)'); "半成品工序" + string((1:3)'); "成品工序"];
NominalRate = sampling.nominalRates(:);
RejectSampleSize = sampling.nReject(:);
AcceptSampleSize = sampling.nAccept(:);
SampleSize = sampling.sampleSize(:);
DefectCount = sampling.defectCount(:);
AlphaPerParameter = repmat(sampling.alphaPerParameter, 12, 1);
LowerBound = sampling.lower(:);
UpperBound = sampling.upper(:);
tableOut = table(Parameter, NominalRate, RejectSampleSize, AcceptSampleSize, ...
    SampleSize, DefectCount, AlphaPerParameter, LowerBound, UpperBound);
end


function [tableOut, simulations, orderedBits] = validate_candidates( ...
    scenario, candidates, trials, baseSeed)
count = size(candidates, 1);
UpperMeanProfit = zeros(count, 1);
CI95Low = zeros(count, 1);
CI95High = zeros(count, 1);
CompletionRate = zeros(count, 1);
simulations = cell(count, 1);
for row = 1:count
    strategy = decode_problem3_chromosome(candidates(row, :));
    simulations{row} = simulate_problem3_strategy(scenario, strategy, trials, ...
        problem3_policy_seed(baseSeed, strategy.bits));
    UpperMeanProfit(row) = simulations{row}.meanProfit;
    CI95Low(row) = simulations{row}.ci95(1);
    CI95High(row) = simulations{row}.ci95(2);
    CompletionRate(row) = simulations{row}.completionRate;
end
[UpperMeanProfit, order] = sort(UpperMeanProfit, 'descend');
orderedBits = candidates(order, :);
simulations = simulations(order);
CI95Low = CI95Low(order);
CI95High = CI95High(order);
CompletionRate = CompletionRate(order);
Chromosome = strings(count, 1);
for row = 1:count
    Chromosome(row) = decode_problem3_chromosome(orderedBits(row, :)).bitString;
end
tableOut = table(Chromosome, UpperMeanProfit, CI95Low, CI95High, CompletionRate);
end


function summary = make_summary(pointStrategy, robustStrategy, pointCenter, ...
    robustCenter, pointUpper, robustUpper)
PointChromosome = string(pointStrategy.bitString);
RobustChromosome = string(robustStrategy.bitString);
PointDescription = string(problem3_strategy_description(pointStrategy));
RobustDescription = string(problem3_strategy_description(robustStrategy));
PointCenterProfit = pointCenter.meanProfit;
RobustCenterProfit = robustCenter.meanProfit;
PointUpperProfit = pointUpper.meanProfit;
RobustUpperProfit = robustUpper.meanProfit;
RobustUpperCI95Low = robustUpper.ci95(1);
RobustUpperCI95High = robustUpper.ci95(2);
RobustnessCost = PointCenterProfit - RobustCenterProfit;
WorstCaseGain = RobustUpperProfit - PointUpperProfit;
SameStrategy = all(pointStrategy.bits == robustStrategy.bits);
summary = table(PointChromosome, RobustChromosome, PointDescription, ...
    RobustDescription, PointCenterProfit, RobustCenterProfit, ...
    PointUpperProfit, RobustUpperProfit, RobustUpperCI95Low, ...
    RobustUpperCI95High, RobustnessCost, WorstCaseGain, SameStrategy);
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


function output = evaluate_validation_scenarios(baseScenario, rates, labels, ...
    pointStrategy, robustStrategy, trials, baseSeed)
policyNames = ["点估计策略"; "稳健策略"];
policies = {pointStrategy; robustStrategy};
rowCount = 2 * size(rates, 1);
PolicyType = strings(rowCount, 1);
Chromosome = strings(rowCount, 1);
Scenario = strings(rowCount, 1);
MeanProfit = zeros(rowCount, 1);
CI95Low = zeros(rowCount, 1);
CI95High = zeros(rowCount, 1);
CompletionRate = zeros(rowCount, 1);
row = 0;
for policyIndex = 1:2
    strategy = policies{policyIndex};
    for scenarioIndex = 1:size(rates, 1)
        changed = problem4_set_problem3_rates(baseScenario, rates(scenarioIndex, :));
        simulation = simulate_problem3_strategy(changed, strategy, trials, ...
            problem3_policy_seed(baseSeed + policyIndex * 100000 + scenarioIndex, ...
            strategy.bits));
        row = row + 1;
        PolicyType(row) = policyNames(policyIndex);
        Chromosome(row) = strategy.bitString;
        Scenario(row) = labels(scenarioIndex);
        MeanProfit(row) = simulation.meanProfit;
        CI95Low(row) = simulation.ci95(1);
        CI95High(row) = simulation.ci95(2);
        CompletionRate(row) = simulation.completionRate;
    end
end
output = table(PolicyType, Chromosome, Scenario, MeanProfit, CI95Low, ...
    CI95High, CompletionRate);
for j = 1:12
    output.("Rate" + j) = repmat(rates(:, j), 2, 1);
end
end


function draw_convergence(histories, outputFile)
figure('Visible', 'off', 'Color', 'w');
plot(1:size(histories, 1), histories, 'LineWidth', 1.2);
xlabel('迭代代数');
ylabel('联合上界情景下的当代最优平均净收益');
legend(compose('独立运行%d', 1:size(histories, 2)), 'Location', 'bestoutside');
grid on;
exportgraphics(gcf, outputFile, 'Resolution', 180);
close(gcf);
end


function write_report(path, summary, intervals, runs, robustStrategy, ...
    validationTrials, scenarioTrials, lhsCount)
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid >= 0, '无法写入问题三实验报告。');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# 问题四：问题三联合置信区间稳健实验\n\n');
fprintf(fid, ['12个次品率均视为合格投入条件下的工序失效率；', ...
    '使用Bonferroni修正的联合95%%精确二项区间，并在联合上界情景下运行38位遗传算法。\n\n']);
fprintf(fid, '- 点估计策略：`%s`\n', char(summary.PointChromosome));
fprintf(fid, '- 稳健策略：`%s`\n', robustStrategy.bitString);
fprintf(fid, '- 稳健策略说明：%s\n', problem3_strategy_description(robustStrategy));
fprintf(fid, '- 点估计策略中心利润：%.4f\n', summary.PointCenterProfit);
fprintf(fid, '- 稳健策略中心利润：%.4f\n', summary.RobustCenterProfit);
fprintf(fid, '- 点估计策略联合上界利润：%.4f\n', summary.PointUpperProfit);
fprintf(fid, '- 稳健策略联合上界利润：%.4f\n', summary.RobustUpperProfit);
fprintf(fid, '- 稳健策略联合上界95%% MC区间：[%.4f, %.4f]\n', ...
    summary.RobustUpperCI95Low, summary.RobustUpperCI95High);
fprintf(fid, '- 稳健代价：%.4f；最坏情景改善：%.4f\n\n', ...
    summary.RobustnessCost, summary.WorstCaseGain);
fprintf(fid, ['GA参数：种群80、100代、适应度样本1200、独立运行6次；', ...
    '候选用%d次仿真复评。验证情景每次%d，LHS情景%d个。\n\n'], ...
    validationTrials, scenarioTrials, lhsCount);
fprintf(fid, '## 独立运行\n\n');
fprintf(fid, '|运行|搜索最优染色体|搜索收益|评价策略数|\n|---:|:---|---:|---:|\n');
for i = 1:height(runs)
    fprintf(fid, '|%d|`%s`|%.4f|%d|\n', runs.Run(i), ...
        char(runs.SearchChromosome(i)), runs.SearchFitness(i), ...
        runs.UniqueEvaluations(i));
end
fprintf(fid, '\n## 抽样区间\n\n');
fprintf(fid, '|参数|样本估计|n|x|下界|上界|\n|:---|---:|---:|---:|---:|---:|\n');
for i = 1:height(intervals)
    fprintf(fid, '|%s|%.4f|%d|%d|%.6f|%.6f|\n', ...
        char(intervals.Parameter(i)), intervals.NominalRate(i), ...
        intervals.SampleSize(i), intervals.DefectCount(i), ...
        intervals.LowerBound(i), intervals.UpperBound(i));
end
end
