function cfg = config_project()

thisFile = mfilename('fullpath');
cfg.platformRoot = fileparts(thisFile);
cfg.workspaceRoot = fileparts(cfg.platformRoot);

cfg.guidedWaveDir = fullfile('D:\codeforothers\2605\导波数据\导波');
cfg.fiberDir = fullfile('D:\codeforothers\2605\导波数据\光纤数据');
cfg.outputRoot = fullfile(cfg.platformRoot, 'outputs');
cfg.figureRoot = fullfile(cfg.outputRoot, 'figures');

if ~exist(cfg.outputRoot, 'dir'), mkdir(cfg.outputRoot); end
if ~exist(cfg.figureRoot, 'dir'), mkdir(cfg.figureRoot); end

cfg.guidedWavePattern = 'F08*_offline.mat';
cfg.guidedWaveIgnore = {'SETUP.mat', 'allReceivedSignals.mat'};
cfg.setupFile = fullfile(cfg.guidedWaveDir, 'SETUP.mat');

cfg.fiberPattern = '*.txt';
cfg.fiberIgnoreContains = {'FATIGUE', 'AE'};


cfg.fsMHz = 12;                
cfg.fs = cfg.fsMHz * 1e6;
cfg.signalLength = 4000;        
cfg.filterOrder = 4;
cfg.bandwidthRatio = 0.35;      % 相对中心频率带宽
cfg.windowSamples = [];        
cfg.defaultPathLabels = { ...
    '1-4', '1-5', '1-6', ...
    '2-4', '2-5', '2-6', ...
    '3-4', '3-5', '3-6'};

% 光纤参数
cfg.fiberSmoothingWindow = 11;    
cfg.fiberGradientWindow = 9;
cfg.fiberDefaultXUnit = 'sample';
cfg.fiberValueColumn = [];         
cfg.fiberXAxisColumn = [];         

cfg.baselineCondition = "N0";   
cfg.stageEdges = [-inf, 0, 5000, 50000, inf];
cfg.stageNames = ["Healthy", "Early", "Middle", "Late"];

cfg.selectedConditions = ["N200", "N5000", "N30000", "N90000"];
cfg.selectedSignalField = "s1_50k";
cfg.selectedFiberConditions = ["N200", "N5000", "N30000", "N63000"];

cfg.guidedDatasetFile = fullfile(cfg.outputRoot, 'dataset_guidedwave.mat');
cfg.fiberDatasetFile = fullfile(cfg.outputRoot, 'dataset_fiber.mat');
cfg.featureFile = fullfile(cfg.outputRoot, 'feature_tables.mat');
cfg.fusedFeatureCsv = fullfile(cfg.outputRoot, 'fused_condition_features.csv');
cfg.modelFile = fullfile(cfg.outputRoot, 'fault_diagnosis_model.mat');

cfg.randomSeed = 42;
rng(cfg.randomSeed);
end
