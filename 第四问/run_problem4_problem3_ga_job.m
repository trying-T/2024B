function outputPath = run_problem4_problem3_ga_job(jobIndex)
%RUN_PROBLEM4_PROBLEM3_GA_JOB 单次正式稳健GA并立即保存检查点。

arguments
    jobIndex (1,1) double {mustBeInteger, mustBePositive}
end
assert(jobIndex <= 6, '正式独立GA作业编号为1至6。');

root = problem4_setup_paths();
jobDir = fullfile(root, 'results_problem3', 'jobs');
if ~exist(jobDir, 'dir')
    mkdir(jobDir);
end

baseScenario = problem3_params();
nominal = [baseScenario.componentDefectRates, ...
    baseScenario.semiDefectRates, baseScenario.finalDefectRate];
sampling = problem4_sampling_intervals(nominal, 12);
upperScenario = problem4_set_problem3_rates(baseScenario, sampling.upper);
baseSeed = 202409;
evaluationSeed = baseSeed + jobIndex * 10000;
config = struct('PopulationSize',80,'Generations',100, ...
    'CrossoverProbability',0.8,'MutationProbability',0.03, ...
    'TournamentSize',3,'EliteCount',2,'Trials',1200, ...
    'EvaluationSeed',evaluationSeed,'CandidateCount',10);

ga = run_problem3_ga(upperScenario, config, evaluationSeed + 17);
outputPath = fullfile(jobDir, sprintf('upper_%02d.mat', jobIndex));
save(outputPath, 'ga', 'config', 'jobIndex');
fprintf('问题四问题三作业%d完成：%s，收益%.4f，已保存%s\n', ...
    jobIndex, decode_problem3_chromosome(ga.bestBits).bitString, ...
    ga.bestFitness, outputPath);
end
