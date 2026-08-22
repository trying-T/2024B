function text = strategy_description(strategy)
%STRATEGY_DESCRIPTION 将二进制策略转换为中文决策。

yn = ["否", "是"];
parts = strings(0, 1);
for j = 1:numel(strategy.inspectNew)
    parts(end + 1) = sprintf('新购件%d检测=%s', j, yn(strategy.inspectNew(j) + 1)); %#ok<AGROW>
end
parts(end + 1) = "成品检测=" + yn(strategy.inspectFinal + 1);
parts(end + 1) = "不合格品拆解=" + yn(strategy.disassemble + 1);
for j = 1:numel(strategy.inspectRecovered)
    parts(end + 1) = sprintf('回收件%d检测=%s、利用=%s', j, ...
        yn(strategy.inspectRecovered(j) + 1), yn(strategy.reuseRecovered(j) + 1)); %#ok<AGROW>
end
text = strjoin(parts, '；');
end

