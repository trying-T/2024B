function results = problem1_binomial_experiment(cfg)
%PROBLEM1_BINOMIAL_EXPERIMENT 问题一：精确二项分布单边抽样实验。
%
%   results = problem1_binomial_experiment()
%   results = problem1_binomial_experiment(cfg)
%
% 模型严格采用两套彼此独立的单边约束：
%   拒收：P_{p0}(X >= xr) <= alphaReject，取最小可行 xr；
%   接收：P_{p0}(X <= xa) <= alphaAccept，取最大可行 xa。
%
% cfg 可选字段：
%   p0                标称次品率，默认 0.10
%   alphaReject       错误拒收概率上限，默认 0.05
%   alphaAccept       错误接收概率上限，默认 0.10
%   nMax              最大枚举样本量，默认 1000
%   epsilon           相对变化稳定阈值，默认 0.01
%   stabilityWindow   连续稳定窗口长度，默认 10
%   minRecommendN     推荐样本量下限，默认 1
%   outputDir         输出目录，默认 results_problem1
%   makePlots         是否绘图，默认 true
%
% 说明：sigma 按题设方案使用临界样本比例计算，而不是在 p0 处计算：
%   sigma = sqrt(phat * (1-phat) / n).

    if nargin < 1
        cfg = struct();
    end
    cfg = fill_defaults(cfg);
    validate_config(cfg);

    n = (1:cfg.nMax)';
    xr = nan(cfg.nMax, 1);
    xa = nan(cfg.nMax, 1);
    probReject = nan(cfg.nMax, 1);
    probAccept = nan(cfg.nMax, 1);

    for i = 1:cfg.nMax
        ni = n(i);

        % 拒收阈值取最小可行值，使拒收域尽可能宽。
        for candidate = 0:ni
            tailProb = binomial_upper_tail(candidate, ni, cfg.p0);
            if tailProb <= cfg.alphaReject
                xr(i) = candidate;
                probReject(i) = tailProb;
                break;
            end
        end

        % 接收阈值取最大可行值，使接收域尽可能宽。
        for candidate = ni:-1:0
            cdfProb = binomial_lower_tail(candidate, ni, cfg.p0);
            if cdfProb <= cfg.alphaAccept
                xa(i) = candidate;
                probAccept(i) = cdfProb;
                break;
            end
        end
    end

    phatReject = xr ./ n;
    phatAccept = xa ./ n;
    sigmaReject = sqrt(phatReject .* (1 - phatReject) ./ n);
    sigmaAccept = sqrt(phatAccept .* (1 - phatAccept) ./ n);
    varianceReject = sigmaReject .^ 2;
    varianceAccept = sigmaAccept .^ 2;

    gainReject = relative_gain(sigmaReject);
    gainAccept = relative_gain(sigmaAccept);

    recommendReject = recommend_n(n, sigmaReject, cfg);
    recommendAccept = recommend_n(n, sigmaAccept, cfg);

    rejectTable = table(n, xr, phatReject, varianceReject, sigmaReject, probReject, gainReject, ...
        'VariableNames', {'n','xr','phat_r','variance_r','sigma_r','tail_probability','relative_gain'});
    acceptTable = table(n, xa, phatAccept, varianceAccept, sigmaAccept, probAccept, gainAccept, ...
        'VariableNames', {'n','xa','phat_a','variance_a','sigma_a','cdf_probability','relative_gain'});

    ensure_output_dir(cfg.outputDir);
    writetable(rejectTable, fullfile(cfg.outputDir, 'reject_thresholds.csv'));
    writetable(acceptTable, fullfile(cfg.outputDir, 'accept_thresholds.csv'));

    if cfg.makePlots
        draw_curve(n, sigmaReject, recommendReject, ...
            '拒收模型：样本量与临界比例标准差', '\sigma_r(n)', ...
            fullfile(cfg.outputDir, 'reject_sigma_curve.png'));
        draw_curve(n, sigmaAccept, recommendAccept, ...
            '接收模型：样本量与临界比例标准差', '\sigma_a(n)', ...
            fullfile(cfg.outputDir, 'accept_sigma_curve.png'));
    end

    rejectChoice = row_at_n(rejectTable, recommendReject);
    acceptChoice = row_at_n(acceptTable, recommendAccept);
    write_summary(cfg, rejectTable, acceptTable, rejectChoice, acceptChoice);

    results = struct();
    results.config = cfg;
    results.rejectTable = rejectTable;
    results.acceptTable = acceptTable;
    results.rejectChoice = rejectChoice;
    results.acceptChoice = acceptChoice;

    print_choice('拒收', rejectChoice, 'X >= xr');
    print_choice('接收', acceptChoice, 'X <= xa');
end


function cfg = fill_defaults(cfg)
    defaults = struct( ...
        'p0', 0.10, ...
        'alphaReject', 0.05, ...
        'alphaAccept', 0.10, ...
        'nMax', 1000, ...
        'epsilon', 0.01, ...
        'stabilityWindow', 10, ...
        'minRecommendN', 1, ...
        'outputDir', 'results_problem1', ...
        'makePlots', true);
    names = fieldnames(defaults);
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(cfg, name) || isempty(cfg.(name))
            cfg.(name) = defaults.(name);
        end
    end
end


function validate_config(cfg)
    assert(isscalar(cfg.p0) && cfg.p0 > 0 && cfg.p0 < 1, 'p0 必须位于 (0,1)。');
    assert(isscalar(cfg.alphaReject) && cfg.alphaReject > 0 && cfg.alphaReject < 1, ...
        'alphaReject 必须位于 (0,1)。');
    assert(isscalar(cfg.alphaAccept) && cfg.alphaAccept > 0 && cfg.alphaAccept < 1, ...
        'alphaAccept 必须位于 (0,1)。');
    assert(isscalar(cfg.nMax) && cfg.nMax == floor(cfg.nMax) && cfg.nMax >= 1, ...
        'nMax 必须是正整数。');
    assert(isscalar(cfg.epsilon) && cfg.epsilon > 0, 'epsilon 必须为正数。');
    assert(isscalar(cfg.stabilityWindow) && cfg.stabilityWindow >= 1 && ...
        cfg.stabilityWindow == floor(cfg.stabilityWindow), 'stabilityWindow 必须是正整数。');
    assert(isscalar(cfg.minRecommendN) && cfg.minRecommendN >= 1, ...
        'minRecommendN 必须为正数。');
end


function probability = binomial_upper_tail(k, n, p)
% P(X >= k)。betainc 属于 MATLAB 基础函数，无需统计工具箱。
    if k <= 0
        probability = 1;
    elseif k > n
        probability = 0;
    else
        probability = betainc(p, k, n - k + 1);
    end
end


function probability = binomial_lower_tail(k, n, p)
% P(X <= k)。
    if k < 0
        probability = 0;
    elseif k >= n
        probability = 1;
    else
        probability = betainc(1 - p, n - k, k + 1);
    end
end


function gain = relative_gain(sigma)
% 与用户给定公式一致；仅在相邻两点均为正且有限时计算。
    gain = nan(size(sigma));
    previous = sigma(1:end-1);
    current = sigma(2:end);
    valid = isfinite(previous) & isfinite(current) & previous > 0;
    temp = nan(size(previous));
    temp(valid) = (previous(valid) - current(valid)) ./ previous(valid);
    gain(2:end) = temp;
end


function chosenN = recommend_n(n, sigma, cfg)
% 先用移动中位数抑制整数临界值引起的锯齿，再要求连续窗口内：
% 0 <= [s(n-1)-s(n)]/s(n-1) < epsilon。
% 若整个枚举区间没有满足条件的窗口，则返回最后一个可行 n。
    chosenN = NaN;
    valid = isfinite(sigma) & sigma > 0 & n >= cfg.minRecommendN;
    if ~any(valid)
        return;
    end

    smoothSigma = nan(size(sigma));
    validIndex = find(valid);
    validSigma = sigma(validIndex);
    windowForMedian = min(5, numel(validSigma));
    smoothSigma(validIndex) = movmedian(validSigma, windowForMedian);
    gains = relative_gain(smoothSigma);
    stable = gains >= 0 & gains < cfg.epsilon & valid;

    runLength = 0;
    for i = 1:numel(n)
        if stable(i)
            runLength = runLength + 1;
            if runLength >= cfg.stabilityWindow
                chosenN = n(i - cfg.stabilityWindow + 1);
                return;
            end
        else
            runLength = 0;
        end
    end
    chosenN = n(validIndex(end));
end


function selected = row_at_n(dataTable, chosenN)
    if isnan(chosenN)
        selected = dataTable([], :);
    else
        selected = dataTable(dataTable.n == chosenN, :);
    end
end


function ensure_output_dir(outputDir)
    if ~isfolder(outputDir)
        [ok, message] = mkdir(outputDir);
        assert(ok, '无法创建输出目录：%s', message);
    end
end


function draw_curve(n, sigma, chosenN, titleText, yLabelText, outputFile)
    fig = figure('Color', 'white', 'Position', [100, 100, 920, 560], 'Visible', 'off');
    plot(n, sigma, 'LineWidth', 1.2, 'Color', [0.10, 0.38, 0.68]);
    grid on;
    box on;
    xlabel('检测数量 n');
    ylabel(yLabelText);
    title(titleText);
    if isfinite(chosenN)
        hold on;
        index = find(n == chosenN, 1);
        plot(chosenN, sigma(index), 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', [0.85, 0.20, 0.15], 'MarkerEdgeColor', 'none');
        xline(chosenN, '--', sprintf('推荐 n=%d', chosenN), ...
            'Color', [0.85, 0.20, 0.15], 'LabelVerticalAlignment', 'bottom');
    end
    exportgraphics(fig, outputFile, 'Resolution', 200);
    close(fig);
end


function write_summary(cfg, rejectTable, acceptTable, rejectChoice, acceptChoice)
    outputFile = fullfile(cfg.outputDir, 'experiment_summary.txt');
    fileId = fopen(outputFile, 'w', 'n', 'UTF-8');
    assert(fileId >= 0, '无法写入实验摘要：%s', outputFile);
    cleaner = onCleanup(@() fclose(fileId)); %#ok<NASGU>

    fprintf(fileId, '问题一：精确二项分布单边抽样实验\n');
    fprintf(fileId, 'p0=%.6f, alphaReject=%.6f, alphaAccept=%.6f\n', ...
        cfg.p0, cfg.alphaReject, cfg.alphaAccept);
    fprintf(fileId, 'nMax=%d, epsilon=%.6f, stabilityWindow=%d, minRecommendN=%d\n\n', ...
        cfg.nMax, cfg.epsilon, cfg.stabilityWindow, cfg.minRecommendN);

    firstReject = find(isfinite(rejectTable.xr), 1, 'first');
    firstAccept = find(isfinite(acceptTable.xa), 1, 'first');
    if isempty(firstReject)
        fprintf(fileId, '枚举范围内不存在可执行的拒收临界值。\n');
    else
        fprintf(fileId, '首个存在可执行拒收临界值的 n=%d。\n', rejectTable.n(firstReject));
    end
    if isempty(firstAccept)
        fprintf(fileId, '枚举范围内不存在可执行的接收临界值。\n\n');
    else
        fprintf(fileId, '首个存在可执行接收临界值的 n=%d。\n\n', acceptTable.n(firstAccept));
    end

    write_choice(fileId, '拒收推荐', rejectChoice, 'xr', 'tail_probability', 'sigma_r', 'X >= xr');
    write_choice(fileId, '接收推荐', acceptChoice, 'xa', 'cdf_probability', 'sigma_a', 'X <= xa');
    fprintf(fileId, ['\n注意：sigma 使用临界比例 x/n 代入二项比例标准误公式；', ...
        '它是选样辅助指标，不等同于 p=p0 时固定的标准误。\n']);
end


function write_choice(fileId, label, choice, thresholdName, probabilityName, sigmaName, rule)
    if isempty(choice)
        fprintf(fileId, '%s：在给定搜索范围内无可推荐结果。\n', label);
        return;
    end
    threshold = choice.(thresholdName)(1);
    fprintf(fileId, '%s：n=%d, %s=%d, %s, 概率=%.12g, sigma=%.12g。\n', ...
        label, choice.n(1), thresholdName, threshold, ...
        strrep(rule, thresholdName, sprintf('%d', threshold)), ...
        choice.(probabilityName)(1), choice.(sigmaName)(1));
end


function print_choice(label, choice, rule)
    if isempty(choice)
        fprintf('%s模型：给定范围内没有可推荐结果。\n', label);
        return;
    end
    fprintf('%s模型推荐行：n = %d，%s。\n', label, choice.n(1), rule);
    disp(choice);
end
