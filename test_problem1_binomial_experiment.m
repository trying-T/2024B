function test_problem1_binomial_experiment()
%TEST_PROBLEM1_BINOMIAL_EXPERIMENT 最小回归测试与约束检查。
    cfg = struct( ...
        'nMax', 120, ...
        'makePlots', false, ...
        'outputDir', fullfile(tempdir, 'cumcm_problem1_matlab_test'));
    results = problem1_binomial_experiment(cfg);
    reject = results.rejectTable;
    accept = results.acceptTable;

    assert(isnan(reject.xr(reject.n == 1)), 'n=1 不应存在可执行拒收阈值。');
    assert(reject.xr(reject.n == 2) == 2, 'n=2 的拒收阈值应为 xr=2。');
    assert(abs(reject.tail_probability(reject.n == 2) - 0.01) < 1e-12);

    assert(all(isnan(accept.xa(accept.n <= 21))), 'n<=21 不应存在可执行接收阈值。');
    assert(accept.xa(accept.n == 22) == 0, 'n=22 的接收阈值应为 xa=0。');
    assert(abs(accept.cdf_probability(accept.n == 22) - 0.9^22) < 1e-12);

    feasibleReject = isfinite(reject.xr);
    feasibleAccept = isfinite(accept.xa);
    assert(all(reject.tail_probability(feasibleReject) <= results.config.alphaReject + 1e-12));
    assert(all(accept.cdf_probability(feasibleAccept) <= results.config.alphaAccept + 1e-12));

    % 验证阈值是最宽可行判定域：xr-1 和 xa+1 必须违反相应约束。
    rejectRows = find(feasibleReject);
    for row = rejectRows'
        n = reject.n(row);
        xr = reject.xr(row);
        if xr > 0
            widerTail = betainc(results.config.p0, xr - 1, n - (xr - 1) + 1);
            assert(widerTail > results.config.alphaReject - 1e-12);
        end
    end
    acceptRows = find(feasibleAccept);
    for row = acceptRows'
        n = accept.n(row);
        xa = accept.xa(row);
        if xa + 1 < n
            widerCdf = betainc(1 - results.config.p0, n - (xa + 1), xa + 2);
            assert(widerCdf > results.config.alphaAccept - 1e-12);
        end
    end

    assert(results.rejectChoice.n == 85, '默认稳定规则的拒收推荐应为 n=85。');
    assert(results.acceptChoice.n == 105, '默认稳定规则的接收推荐应为 n=105。');
    fprintf('全部问题一 MATLAB 测试通过。\n');
end
