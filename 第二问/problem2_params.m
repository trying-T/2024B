function scenarios = problem2_params()
%PROBLEM2_PARAMS 表1六种生产情形。金额单位为元/件。

data = [
    1, 0.10, 4, 2, 0.10, 18, 3, 0.10, 6, 3, 56,  6,  5;
    2, 0.20, 4, 2, 0.20, 18, 3, 0.20, 6, 3, 56,  6,  5;
    3, 0.10, 4, 2, 0.10, 18, 3, 0.10, 6, 3, 56, 30,  5;
    4, 0.20, 4, 1, 0.20, 18, 1, 0.20, 6, 2, 56, 30,  5;
    5, 0.10, 4, 8, 0.20, 18, 1, 0.10, 6, 2, 56, 10,  5;
    6, 0.05, 4, 2, 0.05, 18, 3, 0.05, 6, 3, 56, 10, 40
];

template = struct( ...
    'id', 0, ...
    'componentDefectRates', [], ...
    'purchaseCosts', [], ...
    'componentInspectionCosts', [], ...
    'finalDefectRate', 0, ...
    'assemblyCost', 0, ...
    'finalInspectionCost', 0, ...
    'salePrice', 0, ...
    'exchangeLoss', 0, ...
    'disassemblyCost', 0);
scenarios = repmat(template, size(data, 1), 1);

for k = 1:size(data, 1)
    row = data(k, :);
    scenarios(k).id = row(1);
    scenarios(k).componentDefectRates = [row(2), row(5)];
    scenarios(k).purchaseCosts = [row(3), row(6)];
    scenarios(k).componentInspectionCosts = [row(4), row(7)];
    scenarios(k).finalDefectRate = row(8);
    scenarios(k).assemblyCost = row(9);
    scenarios(k).finalInspectionCost = row(10);
    scenarios(k).salePrice = row(11);
    scenarios(k).exchangeLoss = row(12);
    scenarios(k).disassemblyCost = row(13);
end
end
