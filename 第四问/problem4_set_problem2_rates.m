function scenario = problem4_set_problem2_rates(baseScenario, rates)
%PROBLEM4_SET_PROBLEM2_RATES 仅替换问题二的三个次品率参数。

assert(numel(rates) == 3, '问题二次品率向量长度必须为3。');
scenario = baseScenario;
scenario.componentDefectRates = rates(1:2);
scenario.finalDefectRate = rates(3);
end
