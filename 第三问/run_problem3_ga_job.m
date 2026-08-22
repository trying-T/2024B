function outputPath = run_problem3_ga_job(jobType, jobIndex)
%RUN_PROBLEM3_GA_JOB 单次独立GA作业，完成后立即保存检查点。

arguments
    jobType (1,1) string
    jobIndex (1,1) double {mustBeInteger, mustBePositive}
end

root = fileparts(mfilename('fullpath'));
jobDir = fullfile(root, 'results', 'jobs');
if ~exist(jobDir, 'dir')
    mkdir(jobDir);
end
scenario = problem3_params();
baseSeed = 202408;

if jobType == "base"
    assert(jobIndex <= 6, '基础作业编号为1至6。');
    config = struct('PopulationSize',80,'Generations',100, ...
        'CrossoverProbability',0.8,'MutationProbability',0.03, ...
        'TournamentSize',3,'EliteCount',2,'Trials',1200, ...
        'EvaluationSeed',baseSeed + jobIndex * 10000,'CandidateCount',10);
    scenarioLabel = "base";
    outputPath = fullfile(jobDir, sprintf('base_%02d.mat', jobIndex));
else
    labels = ["defect_-20%", "defect_+20%", "exchange_-20%", "exchange_+20%"];
    labelIndex = find(labels == jobType, 1);
    assert(~isempty(labelIndex), '未知作业类型。');
    assert(jobIndex <= 3, '敏感性作业编号为1至3。');
    scenario = perturb_problem3_scenario(scenario, jobType);
    sensitivitySeed = baseSeed + labelIndex * 1000000;
    config = struct('PopulationSize',60,'Generations',60, ...
        'CrossoverProbability',0.8,'MutationProbability',0.03, ...
        'TournamentSize',3,'EliteCount',2,'Trials',800, ...
        'EvaluationSeed',sensitivitySeed + jobIndex * 10000,'CandidateCount',10);
    scenarioLabel = jobType;
    safeLabel = replace(jobType, ["%", "+", "-"], ["pct", "plus", "minus"]);
    outputPath = fullfile(jobDir, sprintf('%s_%02d.mat', safeLabel, jobIndex));
end

ga = run_problem3_ga(scenario, config, config.EvaluationSeed + 17);
save(outputPath, 'ga', 'config', 'scenarioLabel', 'jobIndex');
fprintf('作业 %s-%d 完成：收益 %.4f，评价 %d 个策略，已保存 %s\n', ...
    jobType, jobIndex, ga.bestFitness, ga.uniqueEvaluations, outputPath);
end

