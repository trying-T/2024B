function scenario = problem4_set_problem3_rates(baseScenario, rates)
%PROBLEM4_SET_PROBLEM3_RATES 仅替换问题三的十二个次品率参数。

assert(numel(rates) == 12, '问题三次品率向量长度必须为12。');
scenario = baseScenario;
scenario.componentDefectRates = rates(1:8);
scenario.semiDefectRates = rates(9:11);
scenario.finalDefectRate = rates(12);
end
