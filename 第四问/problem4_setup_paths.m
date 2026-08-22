function root = problem4_setup_paths()
%PROBLEM4_SETUP_PATHS 将问题二、三既有模型加入MATLAB路径。

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, '..', '第二问'));
addpath(fullfile(root, '..', '第三问'));
end
