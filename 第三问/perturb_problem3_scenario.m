function changed = perturb_problem3_scenario(scenario, label)
%PERTURB_PROBLEM3_SCENARIO 构造敏感性情景。

changed = scenario;
switch string(label)
    case "defect_-20%"
        changed.componentDefectRates = 0.8 * scenario.componentDefectRates;
        changed.semiDefectRates = 0.8 * scenario.semiDefectRates;
        changed.finalDefectRate = 0.8 * scenario.finalDefectRate;
    case "defect_+20%"
        changed.componentDefectRates = 1.2 * scenario.componentDefectRates;
        changed.semiDefectRates = 1.2 * scenario.semiDefectRates;
        changed.finalDefectRate = 1.2 * scenario.finalDefectRate;
    case "exchange_-20%"
        changed.exchangeLoss = 0.8 * scenario.exchangeLoss;
    case "exchange_+20%"
        changed.exchangeLoss = 1.2 * scenario.exchangeLoss;
    otherwise
        error('未知扰动：%s', label);
end
end

