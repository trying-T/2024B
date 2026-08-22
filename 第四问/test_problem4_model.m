function tests = test_problem4_model
%TEST_PROBLEM4_MODEL 问题四统计层和参数映射层测试。

tests = functiontests(localfunctions);
end


function testTenPercentSamplingMatchesProblemOne(testCase)
model = problem4_sampling_intervals([0.10, 0.10, 0.10], 3);
verifyEqual(testCase, model.nReject, [85, 85, 85]);
verifyEqual(testCase, model.nAccept, [105, 105, 105]);
verifyEqual(testCase, model.sampleSize, [105, 105, 105]);
verifyEqual(testCase, model.defectCount, [11, 11, 11]);
end


function testBonferroniLevels(testCase)
model2 = problem4_sampling_intervals([0.10, 0.10, 0.10], 3);
model3 = problem4_sampling_intervals(0.10 * ones(1, 12), 12);
verifyEqual(testCase, model2.alphaPerParameter, 0.05 / 3, 'AbsTol', 1e-15);
verifyEqual(testCase, model3.alphaPerParameter, 0.05 / 12, 'AbsTol', 1e-15);
verifyGreaterThan(testCase, model3.upper(1), model2.upper(1));
verifyLessThan(testCase, model3.lower(1), model2.lower(1));
end


function testIntervalsContainNominalRates(testCase)
model = problem4_sampling_intervals([0.05, 0.10, 0.20], 3);
verifyLessThan(testCase, model.lower, model.nominalRates);
verifyGreaterThan(testCase, model.upper, model.nominalRates);
end


function testProblem2RateMappingPreservesCosts(testCase)
problem4_setup_paths();
base = problem2_params();
changed = problem4_set_problem2_rates(base(1), [0.03, 0.12, 0.21]);
verifyEqual(testCase, changed.componentDefectRates, [0.03, 0.12]);
verifyEqual(testCase, changed.finalDefectRate, 0.21);
verifyEqual(testCase, changed.purchaseCosts, base(1).purchaseCosts);
verifyEqual(testCase, changed.exchangeLoss, base(1).exchangeLoss);
end


function testProblem3RateMappingPreservesTopology(testCase)
problem4_setup_paths();
base = problem3_params();
rates = linspace(0.03, 0.14, 12);
changed = problem4_set_problem3_rates(base, rates);
verifyEqual(testCase, changed.componentDefectRates, rates(1:8));
verifyEqual(testCase, changed.semiDefectRates, rates(9:11));
verifyEqual(testCase, changed.finalDefectRate, rates(12));
verifyEqual(testCase, changed.componentGroups, base.componentGroups);
verifyEqual(testCase, changed.purchaseCosts, base.purchaseCosts);
end


function testLHSInsideIntervals(testCase)
lower = [0.01, 0.05, 0.10];
upper = [0.08, 0.15, 0.30];
scenarios = problem4_lhs(lower, upper, 40, 202409);
verifySize(testCase, scenarios, [40, 3]);
verifyGreaterThanOrEqual(testCase, scenarios, repmat(lower, 40, 1));
verifyLessThanOrEqual(testCase, scenarios, repmat(upper, 40, 1));
end
