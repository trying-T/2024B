function strategies = enumerate_strategies(componentCount)
%ENUMERATE_STRATEGIES 枚举并去重全部有实际语义的策略。

chromosomeLength = 3 * componentCount + 2;
raw = dec2bin(0 : 2^chromosomeLength - 1, chromosomeLength) - '0';
canonical = zeros(size(raw));
for i = 1:size(raw, 1)
    decoded = decode_chromosome(raw(i, :), componentCount);
    canonical(i, :) = decoded.bits;
end
strategies = unique(canonical, 'rows', 'stable');
end

