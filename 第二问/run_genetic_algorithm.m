function output = run_genetic_algorithm(scenario, config, seed)
%RUN_GENETIC_ALGORITHM 二进制GA：锦标赛、均匀交叉、位变异、精英保留。

rng(seed, 'twister');
m = numel(scenario.componentDefectRates);
chromosomeLength = 3 * m + 2;
population = randi([0, 1], config.PopulationSize, chromosomeLength);
population = repair_population(population, m);
fitnessCache = containers.Map('KeyType', 'char', 'ValueType', 'double');
history = zeros(config.Generations, 1);

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
        mutationMask1 = rand(1, chromosomeLength) < config.MutationProbability;
        mutationMask2 = rand(1, chromosomeLength) < config.MutationProbability;
        child1(mutationMask1) = 1 - child1(mutationMask1);
        child2(mutationMask2) = 1 - child2(mutationMask2);
        children = repair_population([child1; child2], m);
        remaining = config.PopulationSize - size(nextPopulation, 1);
        nextPopulation = [nextPopulation; children(1:min(2, remaining), :)]; %#ok<AGROW>
    end
    population = nextPopulation;
end

fitness = evaluate_population(population);
[bestFitness, index] = max(fitness);
output.bestBits = population(index, :);
output.bestFitness = bestFitness;
output.history = history;
output.uniqueEvaluations = fitnessCache.Count;

    function values = evaluate_population(candidates)
        values = zeros(size(candidates, 1), 1);
        for row = 1:size(candidates, 1)
            bits = decode_chromosome(candidates(row, :), m).bits;
            key = sprintf('%d', bits);
            if ~isKey(fitnessCache, key)
                policyCode = sum(bits .* 2 .^ (0 : chromosomeLength - 1));
                policySeed = config.EvaluationSeed + 1000003 * policyCode;
                simulation = simulate_strategy(scenario, ...
                    decode_chromosome(bits, m), config.Trials, policySeed);
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


function repaired = repair_population(population, componentCount)
repaired = zeros(size(population));
for row = 1:size(population, 1)
    repaired(row, :) = decode_chromosome(population(row, :), componentCount).bits;
end
end
