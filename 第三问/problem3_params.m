function scenario = problem3_params()
%PROBLEM3_PARAMS 表2两道工序、8个零件的参数。

scenario.componentGroups = {1:3, 4:6, 7:8};
scenario.componentDefectRates = 0.10 * ones(1, 8);
scenario.purchaseCosts = [2, 8, 12, 2, 8, 12, 8, 12];
scenario.componentInspectionCosts = [1, 1, 2, 1, 1, 2, 1, 2];
scenario.semiDefectRates = 0.10 * ones(1, 3);
scenario.semiAssemblyCosts = 8 * ones(1, 3);
scenario.semiInspectionCosts = 4 * ones(1, 3);
scenario.semiDisassemblyCosts = 6 * ones(1, 3);
scenario.finalDefectRate = 0.10;
scenario.finalAssemblyCost = 8;
scenario.finalInspectionCost = 6;
scenario.finalDisassemblyCost = 10;
scenario.salePrice = 200;
scenario.exchangeLoss = 40;
end

