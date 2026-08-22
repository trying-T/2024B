function strategy = decode_chromosome(bits, componentCount)
%DECODE_CHROMOSOME 解码并清除无效决策位。
% 编码：[x_1...x_m, y, z, r_1...r_m, u_1...u_m]

bits = double(logical(bits(:)'));
expectedLength = 3 * componentCount + 2;
assert(numel(bits) == expectedLength, '染色体长度应为 %d。', expectedLength);

strategy.inspectNew = bits(1:componentCount);
strategy.inspectFinal = bits(componentCount + 1);
strategy.disassemble = bits(componentCount + 2);
strategy.inspectRecovered = bits(componentCount + 3 : 2 * componentCount + 2);
strategy.reuseRecovered = bits(2 * componentCount + 3 : end);

if ~strategy.disassemble
    strategy.inspectRecovered(:) = 0;
    strategy.reuseRecovered(:) = 0;
else
    strategy.inspectRecovered(~logical(strategy.reuseRecovered)) = 0;
end

strategy.bits = [strategy.inspectNew, strategy.inspectFinal, ...
    strategy.disassemble, strategy.inspectRecovered, strategy.reuseRecovered];
strategy.bitString = sprintf('%s|%d%d|%s|%s', ...
    sprintf('%d', strategy.inspectNew), strategy.inspectFinal, ...
    strategy.disassemble, sprintf('%d', strategy.inspectRecovered), ...
    sprintf('%d', strategy.reuseRecovered));
end

