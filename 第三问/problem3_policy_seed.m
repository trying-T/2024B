function seed = problem3_policy_seed(baseSeed, bits)
%PROBLEM3_POLICY_SEED 将长染色体稳定映射到合法随机种子。

hash = 0;
modulus = 2147483647;
for value = double(logical(bits(:)'))
    hash = mod(hash * 131 + value + 1, modulus);
end
seed = mod(double(baseSeed) + hash, modulus - 1) + 1;
end

