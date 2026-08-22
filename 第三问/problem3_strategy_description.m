function text = problem3_strategy_description(strategy)
%PROBLEM3_STRATEGY_DESCRIPTION 输出紧凑中文策略说明。

findText = @(values) index_text(find(values));
text = sprintf(['新购零件检测={%s}；半成品检测={%s}；成品检测=%s；' ...
    '半成品拆解={%s}；成品拆解=%s；回收零件检测={%s}、利用={%s}；' ...
    '回收半成品检测={%s}、利用={%s}'], ...
    findText(strategy.inspectNew), findText(strategy.inspectSemi), ...
    yes_no(strategy.inspectFinal), findText(strategy.disassembleSemi), ...
    yes_no(strategy.disassembleFinal), findText(strategy.inspectRecoveredParts), ...
    findText(strategy.reuseRecoveredParts), findText(strategy.inspectRecoveredSemis), ...
    findText(strategy.reuseRecoveredSemis));
end


function output = index_text(indices)
if isempty(indices)
    output = '无';
else
    output = strjoin(string(indices), ',');
end
end


function output = yes_no(value)
if value
    output = '是';
else
    output = '否';
end
end

