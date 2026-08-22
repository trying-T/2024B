function outputs = finalize_problem3_jobs()
%FINALIZE_PROBLEM3_JOBS 汇总独立作业，执行统一大样本复评并输出结果。

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root, 'results');
jobDir = fullfile(resultDir, 'jobs');
scenario = problem3_params();
baseSeed = 202408;

baseFiles = strings(6, 1);
for i = 1:6
    baseFiles(i) = fullfile(jobDir, sprintf('base_%02d.mat', i));
end
[bestBits, bestSimulation, runs, histories, candidateTable] = ...
    validate_jobs(baseFiles, scenario, 300000, baseSeed + 500000);
bestStrategy = decode_problem3_chromosome(bestBits);

benchmarkBits = create_benchmarks_local();
benchmarkNames = ["全部不检测不拆解"; "各层检测且拆解回用"; "分层质控直接回用"; "只检半成品和成品"];
benchmarkRows = struct([]);
for k = 1:4
    strategy = decode_problem3_chromosome(benchmarkBits(k, :));
    simulation = simulate_problem3_strategy(scenario, strategy, 300000, ...
        problem3_policy_seed(baseSeed + 500000, strategy.bits));
    benchmarkRows(k).name = benchmarkNames(k);
    benchmarkRows(k).chromosome = strategy.bitString;
    benchmarkRows(k).meanProfit = simulation.meanProfit;
    benchmarkRows(k).ci95Low = simulation.ci95(1);
    benchmarkRows(k).ci95High = simulation.ci95(2);
end
benchmarkTable = struct2table(benchmarkRows);

labels = ["defect_-20%", "defect_+20%", "exchange_-20%", "exchange_+20%"];
sensitivityRows = struct([]);
for k = 1:4
    safeLabel = replace(labels(k), ["%", "+", "-"], ["pct", "plus", "minus"]);
    files = strings(3, 1);
    for j = 1:3
        files(j) = fullfile(jobDir, sprintf('%s_%02d.mat', safeLabel, j));
    end
    changed = perturb_problem3_scenario(scenario, labels(k));
    [sensitiveBits, sensitiveSimulation] = validate_jobs( ...
        files, changed, 100000, baseSeed + k * 1000000 + 500000);
    sensitivityRows(k).perturbation = labels(k);
    sensitivityRows(k).chromosome = decode_problem3_chromosome(sensitiveBits).bitString;
    sensitivityRows(k).meanProfit = sensitiveSimulation.meanProfit;
    sensitivityRows(k).sameAsBase = all(sensitiveBits == bestBits);
end
sensitivityTable = struct2table(sensitivityRows);

writetable(runs, fullfile(resultDir, 'ga_runs.csv'));
writetable(candidateTable, fullfile(resultDir, 'validated_candidates.csv'));
writetable(benchmarkTable, fullfile(resultDir, 'benchmark_comparison.csv'));
writetable(sensitivityTable, fullfile(resultDir, 'sensitivity.csv'));
summaryTable = make_summary(bestStrategy, bestSimulation, runs);
writetable(summaryTable, fullfile(resultDir, 'optimal_strategy.csv'));

figure('Visible', 'off', 'Color', 'w');
plot(1:size(histories,1), histories, 'LineWidth', 1.25);
xlabel('迭代代数'); ylabel('当代最优平均净收益');
legend(compose('独立运行%d', 1:6), 'Location', 'southeast'); grid on;
exportgraphics(gcf, fullfile(resultDir, 'ga_convergence.png'), 'Resolution', 180);
close(gcf);

write_report_local(fullfile(resultDir, 'experiment_report.md'), bestStrategy, ...
    bestSimulation, runs, benchmarkTable, sensitivityTable);
save(fullfile(resultDir, 'workspace_results.mat'), 'scenario', 'bestStrategy', ...
    'bestSimulation', 'runs', 'candidateTable', 'benchmarkTable', ...
    'sensitivityTable', 'histories');
outputs = struct('bestStrategy',bestStrategy,'bestSimulation',bestSimulation, ...
    'runs',runs,'candidates',candidateTable,'benchmarks',benchmarkTable, ...
    'sensitivity',sensitivityTable,'histories',histories);
fprintf('汇总完成：%s，平均净收益 %.4f。\n', bestStrategy.bitString, bestSimulation.meanProfit);
end


function [bestBits, bestSimulation, runs, histories, candidateTable] = ...
    validate_jobs(files, scenario, validationTrials, validationSeed)

allCandidates = zeros(0, 38);
runCount = numel(files);
runIndex = (1:runCount)';
runChromosome = strings(runCount,1); searchFitness = zeros(runCount,1);
uniqueEvaluations = zeros(runCount,1); histories = [];
for i = 1:runCount
    assert(isfile(files(i)), '缺少作业文件：%s', files(i));
    loaded = load(files(i), 'ga'); ga = loaded.ga;
    repairedCandidates = zeros(size(ga.candidateBits));
    for row = 1:size(ga.candidateBits, 1)
        repairedCandidates(row, :) = ...
            decode_problem3_chromosome(ga.candidateBits(row, :)).bits;
    end
    allCandidates = [allCandidates; repairedCandidates]; %#ok<AGROW>
    if isempty(histories), histories = zeros(numel(ga.history), runCount); end
    histories(:,i) = ga.history;
    runChromosome(i) = decode_problem3_chromosome(ga.bestBits).bitString;
    searchFitness(i) = ga.bestFitness;
    uniqueEvaluations(i) = ga.uniqueEvaluations;
end
allCandidates = unique([allCandidates; create_benchmarks_local()], 'rows', 'stable');
n = size(allCandidates,1);
meanProfit = zeros(n,1); ciLow = zeros(n,1); ciHigh = zeros(n,1);
completionRate = zeros(n,1); simulations = cell(n,1);
for i = 1:n
    strategy = decode_problem3_chromosome(allCandidates(i,:));
    simulations{i} = simulate_problem3_strategy(scenario, strategy, validationTrials, ...
        problem3_policy_seed(validationSeed, strategy.bits));
    meanProfit(i) = simulations{i}.meanProfit;
    ciLow(i) = simulations{i}.ci95(1); ciHigh(i) = simulations{i}.ci95(2);
    completionRate(i) = simulations{i}.completionRate;
end
[meanProfit, order] = sort(meanProfit, 'descend');
allCandidates = allCandidates(order,:); simulations = simulations(order);
ciLow = ciLow(order); ciHigh = ciHigh(order); completionRate = completionRate(order);
bestBits = allCandidates(1,:); bestSimulation = simulations{1};
chromosome = strings(n,1);
for i=1:n, chromosome(i)=decode_problem3_chromosome(allCandidates(i,:)).bitString; end
candidateTable = table(chromosome,meanProfit,ciLow,ciHigh,completionRate, ...
    'VariableNames',{'Chromosome','MeanProfit','CI95Low','CI95High','CompletionRate'});
runs = table(runIndex,runChromosome,searchFitness,uniqueEvaluations, ...
    'VariableNames',{'Run','SearchChromosome','SearchFitness','UniqueEvaluations'});
end


function rows = create_benchmarks_local()
rows = zeros(4,38);
rows(1,:)=decode_problem3_chromosome(zeros(1,38)).bits;
rows(2,:)=decode_problem3_chromosome(ones(1,38)).bits;
rows(3,:)=decode_problem3_chromosome([ones(1,8),ones(1,3),0,ones(1,3),1, ...
    zeros(1,8),ones(1,8),zeros(1,3),ones(1,3)]).bits;
rows(4,:)=decode_problem3_chromosome([zeros(1,8),ones(1,3),1,ones(1,3),1, ...
    ones(1,8),ones(1,8),ones(1,3),ones(1,3)]).bits;
end


function output = make_summary(strategy, simulation, runs)
Chromosome=string(strategy.bitString); Description=string(problem3_strategy_description(strategy));
MeanProfit=simulation.meanProfit; CI95Low=simulation.ci95(1); CI95High=simulation.ci95(2);
CompletionRate=simulation.completionRate; MeanSemiAssemblies=simulation.meanSemiAssemblies;
MeanFinalAssemblies=simulation.meanFinalAssemblies; MeanMarketReturns=simulation.meanMarketReturns;
MeanSemiDisassemblies=simulation.meanSemiDisassemblies;
MeanFinalDisassemblies=simulation.meanFinalDisassemblies;
ExactSearchWinnerCount=sum(runs.SearchChromosome==Chromosome); IndependentRuns=height(runs);
output=table(Chromosome,Description,MeanProfit,CI95Low,CI95High,CompletionRate, ...
    MeanSemiAssemblies,MeanFinalAssemblies,MeanMarketReturns,MeanSemiDisassemblies, ...
    MeanFinalDisassemblies,ExactSearchWinnerCount,IndependentRuns);
end


function write_report_local(path,strategy,simulation,runs,benchmarks,sensitivity)
fid=fopen(path,'w','n','UTF-8'); cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# 问题三分层随机闭环—蒙特卡洛—遗传算法实验结果\n\n');
fprintf(fid,'染色体：`X(8)|H(3)|Y|D(3)|Z|R(8)|U(8)|S(3)|V(3)`，共38位。\n\n');
fprintf(fid,'- 最优染色体：`%s`\n- 决策：%s\n',strategy.bitString,problem3_strategy_description(strategy));
fprintf(fid,'- 平均净收益：%.4f 元/次合格交付\n- 95%%区间：[%.4f, %.4f]\n', ...
    simulation.meanProfit,simulation.ci95(1),simulation.ci95(2));
fprintf(fid,'- 闭环完成率：%.6f；平均半成品/成品装配次数：%.4f/%.4f\n', ...
    simulation.completionRate,simulation.meanSemiAssemblies,simulation.meanFinalAssemblies);
fprintf(fid,'- 平均市场退回/半成品拆解/成品拆解次数：%.4f/%.4f/%.4f\n\n', ...
    simulation.meanMarketReturns,simulation.meanSemiDisassemblies,simulation.meanFinalDisassemblies);
fprintf(fid,'基础搜索采用种群80、100代、适应度样本1200、6次独立运行；候选用300000次独立仿真复评。空间为2^38，因此结果是重复启发式搜索发现的最优解，不宣称严格全局最优。\n\n');
fprintf(fid,'## 独立运行\n\n|运行|搜索染色体|搜索收益|评价策略数|\n|---:|:---|---:|---:|\n');
for i=1:height(runs), fprintf(fid,'|%d|`%s`|%.4f|%d|\n',runs.Run(i),char(runs.SearchChromosome(i)),runs.SearchFitness(i),runs.UniqueEvaluations(i)); end
fprintf(fid,'\n## 基准对比\n\n|基准|收益|95%%区间|\n|:---|---:|:---:|\n');
for i=1:height(benchmarks), fprintf(fid,'|%s|%.4f|[%.4f, %.4f]|\n',char(string(benchmarks.name(i))),benchmarks.meanProfit(i),benchmarks.ci95Low(i),benchmarks.ci95High(i)); end
fprintf(fid,'\n## 敏感性\n\n|扰动|重新优化染色体|收益|与基准相同|\n|:---|:---|---:|:---:|\n');
for i=1:height(sensitivity), fprintf(fid,'|%s|`%s`|%.4f|%d|\n',char(string(sensitivity.perturbation(i))),char(string(sensitivity.chromosome(i))),sensitivity.meanProfit(i),sensitivity.sameAsBase(i)); end
end
