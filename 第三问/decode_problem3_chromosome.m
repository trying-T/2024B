function strategy = decode_problem3_chromosome(bits)
%DECODE_PROBLEM3_CHROMOSOME 解码38位分层闭环策略。
% X(8)|H(3)|Y|D(3)|Z|R(8)|U(8)|S(3)|V(3)
% X:新件检测 H:半成品检测 Y:成品检测 D:半成品拆解 Z:成品拆解
% R/U:回收零件检测/利用 S/V:回收半成品检测/利用

bits = double(logical(bits(:)'));
assert(numel(bits) == 38, '问题三染色体长度必须为38。');

strategy.inspectNew = bits(1:8);
strategy.inspectSemi = bits(9:11);
strategy.inspectFinal = bits(12);
strategy.disassembleSemi = bits(13:15);
strategy.disassembleFinal = bits(16);
strategy.inspectRecoveredParts = bits(17:24);
strategy.reuseRecoveredParts = bits(25:32);
strategy.inspectRecoveredSemis = bits(33:35);
strategy.reuseRecoveredSemis = bits(36:38);

groups = {1:3, 4:6, 7:8};
for j = 1:3
    if ~strategy.disassembleSemi(j)
        group = groups{j};
        strategy.inspectRecoveredParts(group) = 0;
        strategy.reuseRecoveredParts(group) = 0;
    end
end
strategy.inspectRecoveredParts(~logical(strategy.reuseRecoveredParts)) = 0;
% 在检测完全准确、拆解不损伤的假设下，已通过新件检测的零件
% 在后续闭环中质量已知，重复检测严格增加成本，故归零。
strategy.inspectRecoveredParts(logical(strategy.inspectNew)) = 0;
if ~strategy.disassembleFinal
    strategy.inspectRecoveredSemis(:) = 0;
    strategy.reuseRecoveredSemis(:) = 0;
else
    strategy.inspectRecoveredSemis(~logical(strategy.reuseRecoveredSemis)) = 0;
end
% 已通过半成品检测且拆解不损伤时，回收半成品无需重复检测。
strategy.inspectRecoveredSemis(logical(strategy.inspectSemi)) = 0;

strategy.bits = [strategy.inspectNew, strategy.inspectSemi, ...
    strategy.inspectFinal, strategy.disassembleSemi, strategy.disassembleFinal, ...
    strategy.inspectRecoveredParts, strategy.reuseRecoveredParts, ...
    strategy.inspectRecoveredSemis, strategy.reuseRecoveredSemis];
strategy.bitString = sprintf('%s|%s|%d|%s|%d|%s|%s|%s|%s', ...
    sprintf('%d', strategy.inspectNew), sprintf('%d', strategy.inspectSemi), ...
    strategy.inspectFinal, sprintf('%d', strategy.disassembleSemi), ...
    strategy.disassembleFinal, sprintf('%d', strategy.inspectRecoveredParts), ...
    sprintf('%d', strategy.reuseRecoveredParts), ...
    sprintf('%d', strategy.inspectRecoveredSemis), ...
    sprintf('%d', strategy.reuseRecoveredSemis));
end
