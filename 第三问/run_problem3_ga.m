function output = run_problem3_ga(scenario, config, seed)
%RUN_PROBLEM3_GA 38位二进制遗传算法。

rng(seed, 'twister');
chromosomeLength = 38;
population = randi([0, 1], config.PopulationSize, chromosomeLength);
population = repair_population(population);
fitnessCache = containers.Map('KeyType', 'char', 'ValueType', 'double');
history = zeros(config.Generations, 1);

% 加入有解释的极端策略，避免初始种群完全遗漏基线。
population(1, :) = decode_problem3_chromosome(zeros(1, 38)).bits;
population(2, :) = decode_problem3_chromosome(ones(1, 38)).bits;
% 分层质控基线：新件和半成品全检，成品不检；两层均拆解，
% 回收对象不复检而直接利用（上游已保证状态合格）。
layeredBaseline = [ones(1,8), ones(1,3), 0, ones(1,3), 1, ...
    zeros(1,8), ones(1,8), zeros(1,3), ones(1,3)];
population(3, :) = decode_problem3_chromosome(layeredBaseline).bits;

for generation = 1:config.Generations
    fitness = evaluate_population(population);
    [fitness, order] = sort(fitness, 'descend');
    population = population(order, :);
    history(generation) = fitness(1);
    nextPopulation = population(1:config.EliteCount, :);
    while size(nextPopulation, 1) < config.PopulationSize
        parent1 = tournament_pick(population, fitness);
        parent2 = tournament_pick(population, fitness);
        child1 = parent1;
        child2 = parent2;
        if rand < config.CrossoverProbability
            mask = rand(1, chromosomeLength) < 0.5;
            child1(mask) = parent2(mask);
            child2(mask) = parent1(mask);
        end
        mutation1 = rand(1, chromosomeLength) < config.MutationProbability;
        mutation2 = rand(1, chromosomeLength) < config.MutationProbability;
        child1(mutation1) = 1 - child1(mutation1);
        child2(mutation2) = 1 - child2(mutation2);
        children = repair_population([child1; child2]);
        remaining = config.PopulationSize - size(nextPopulation, 1);
        nextPopulation = [nextPopulation; children(1:min(2, remaining), :)]; %#ok<AGROW>
    end
    population = nextPopulation;
end

fitness = evaluate_population(population);
[fitness, order] = sort(fitness, 'descend');
population = population(order, :);
keep = min(config.CandidateCount, size(population, 1));
output.candidateBits = unique(population(1:keep, :), 'rows', 'stable');
output.bestBits = population(1, :);
output.bestFitness = fitness(1);
output.history = history;
output.uniqueEvaluations = fitnessCache.Count;

    function values = evaluate_population(candidates)
        values = zeros(size(candidates, 1), 1);
        for row = 1:size(candidates, 1)
            bits = decode_problem3_chromosome(candidates(row, :)).bits;
            key = sprintf('%d', bits);
            if ~isKey(fitnessCache, key)
                simulation = simulate_problem3_strategy(scenario, ...
                    decode_problem3_chromosome(bits), config.Trials, ...
                    problem3_policy_seed(config.EvaluationSeed, bits));
                fitnessCache(key) = simulation.meanProfit;
            end
            values(row) = fitnessCache(key);
        end
    end

    function parent = tournament_pick(candidates, values)
        selected = randperm(size(candidates, 1), config.TournamentSize);
        [~, localBest] = max(values(selected));
        parent = candidates(selected(localBest), :);
    end
end


function repaired = repair_population(population)
repaired = zeros(size(population));
for row = 1:size(population, 1)
    repaired(row, :) = decode_problem3_chromosome(population(row, :)).bits;
end
end
