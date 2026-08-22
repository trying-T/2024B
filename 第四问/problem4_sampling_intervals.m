function model = problem4_sampling_intervals(nominalRates, familySize)
%PROBLEM4_SAMPLING_INTERVALS 按既定问题四口径构造联合95%置信区间。
%
% 1. 将题目表中的次品率作为样本估计；
% 2. 对每个名义次品率复用问题一的样本量推荐规则；
% 3. 取接收、拒收两个推荐样本量中的较大值；
% 4. x = round(n * pHat)；
% 5. 使用Bonferroni修正后的Clopper-Pearson精确区间。

nominalRates = nominalRates(:)';
assert(all(nominalRates > 0 & nominalRates < 1), ...
    '题目表中的次品率必须位于(0,1)。');
assert(isscalar(familySize) && familySize == numel(nominalRates), ...
    'familySize必须等于同一联合置信域中的参数个数。');

alphaFamily = 0.05;
alphaPerParameter = alphaFamily / familySize;
count = numel(nominalRates);
nReject = zeros(1, count);
nAccept = zeros(1, count);
sampleSize = zeros(1, count);
defectCount = zeros(1, count);
lower = zeros(1, count);
upper = zeros(1, count);

uniqueRates = unique(nominalRates, 'stable');
uniqueReject = zeros(size(uniqueRates));
uniqueAccept = zeros(size(uniqueRates));
for k = 1:numel(uniqueRates)
    [uniqueReject(k), uniqueAccept(k)] = recommend_sample_sizes(uniqueRates(k));
end

for j = 1:count
    matched = find(uniqueRates == nominalRates(j), 1);
    nReject(j) = uniqueReject(matched);
    nAccept(j) = uniqueAccept(matched);
    sampleSize(j) = max(nReject(j), nAccept(j));
    defectCount(j) = round(sampleSize(j) * nominalRates(j));
    [lower(j), upper(j)] = exact_interval( ...
        defectCount(j), sampleSize(j), alphaPerParameter);
end

model.familySize = familySize;
model.alphaFamily = alphaFamily;
model.alphaPerParameter = alphaPerParameter;
model.marginalConfidence = 1 - alphaPerParameter;
model.nominalRates = nominalRates;
model.nReject = nReject;
model.nAccept = nAccept;
model.sampleSize = sampleSize;
model.defectCount = defectCount;
model.lower = lower;
model.upper = upper;
end


function [nReject, nAccept] = recommend_sample_sizes(p0)
% 与问题一相同的精确单边阈值与稳定窗口规则。
nMax = 1000;
epsilon = 0.01;
stabilityWindow = 10;
n = (1:nMax)';
xr = nan(nMax, 1);
xa = nan(nMax, 1);

for i = 1:nMax
    ni = n(i);
    for candidate = 0:ni
        if binomial_upper_tail(candidate, ni, p0) <= 0.05
            xr(i) = candidate;
            break;
        end
    end
    for candidate = ni:-1:0
        if binomial_lower_tail(candidate, ni, p0) <= 0.10
            xa(i) = candidate;
            break;
        end
    end
end

sigmaReject = sqrt((xr ./ n) .* (1 - xr ./ n) ./ n);
sigmaAccept = sqrt((xa ./ n) .* (1 - xa ./ n) ./ n);
nReject = recommend_n(n, sigmaReject, epsilon, stabilityWindow);
nAccept = recommend_n(n, sigmaAccept, epsilon, stabilityWindow);
end


function chosenN = recommend_n(n, sigma, epsilon, stabilityWindow)
valid = isfinite(sigma) & sigma > 0;
assert(any(valid), '给定枚举范围内没有可推荐样本量。');
smoothSigma = nan(size(sigma));
validIndex = find(valid);
validSigma = sigma(validIndex);
smoothSigma(validIndex) = movmedian(validSigma, min(5, numel(validSigma)));
gains = relative_gain(smoothSigma);
stable = gains >= 0 & gains < epsilon & valid;

runLength = 0;
for i = 1:numel(n)
    if stable(i)
        runLength = runLength + 1;
        if runLength >= stabilityWindow
            chosenN = n(i - stabilityWindow + 1);
            return;
        end
    else
        runLength = 0;
    end
end
chosenN = n(validIndex(end));
end


function gain = relative_gain(sigma)
gain = nan(size(sigma));
previous = sigma(1:end-1);
current = sigma(2:end);
valid = isfinite(previous) & isfinite(current) & previous > 0;
temp = nan(size(previous));
temp(valid) = (previous(valid) - current(valid)) ./ previous(valid);
gain(2:end) = temp;
end


function probability = binomial_upper_tail(k, n, p)
if k <= 0
    probability = 1;
elseif k > n
    probability = 0;
else
    probability = betainc(p, k, n - k + 1);
end
end


function probability = binomial_lower_tail(k, n, p)
if k < 0
    probability = 0;
elseif k >= n
    probability = 1;
else
    probability = betainc(1 - p, n - k, k + 1);
end
end


function [lower, upper] = exact_interval(x, n, alpha)
if x == 0
    lower = 0;
else
    lower = betaincinv(alpha / 2, x, n - x + 1);
end
if x == n
    upper = 1;
else
    upper = betaincinv(1 - alpha / 2, x + 1, n - x);
end
end
