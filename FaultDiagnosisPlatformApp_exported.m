classdef FaultDiagnosisPlatformApp_exported < matlab.apps.AppBase
    % FaultDiagnosisPlatformApp_exported
    % 导波-光纤故障诊断平台 GUI（程序化 App Designer 风格）
    %
    % 运行方式：
    %   app = FaultDiagnosisPlatformApp_exported;
    %
    % 说明：
    % 1) 适配目录结构：
    %    工程目录/
    %      ├─ 导波数据/*.mat
    %      ├─ 光纤数据/*.txt
    %      └─ outputs_app/
    % 2) 将第二版样本组织方式与第一版时频图/工况图整合到一个界面中。
    % 3) 为兼容较旧 MATLAB，统计部分避免使用 skewness(...,'omitnan') 这类写法。

    properties (Access = public)
        UIFigure matlab.ui.Figure
        MainGrid matlab.ui.container.GridLayout
        LeftPanel matlab.ui.container.Panel
        LeftGrid matlab.ui.container.GridLayout

        ProjectRootField matlab.ui.control.EditField
        GuidedWaveDirField matlab.ui.control.EditField
        FiberDirField matlab.ui.control.EditField
        OutputDirField matlab.ui.control.EditField

        ChooseProjectButton matlab.ui.control.Button
        ChooseGWButton matlab.ui.control.Button
        ChooseFiberButton matlab.ui.control.Button
        ChooseOutputButton matlab.ui.control.Button

        ImportGWButton matlab.ui.control.Button
        ImportFiberButton matlab.ui.control.Button
        ImportAllButton matlab.ui.control.Button
        ExtractFeaturesButton matlab.ui.control.Button
        RefreshAnalysisButton matlab.ui.control.Button
        RunDiagnosisButton matlab.ui.control.Button
        SaveWorkspaceButton matlab.ui.control.Button

        StatusLamp matlab.ui.control.Lamp
        StatusLabel matlab.ui.control.Label
        LogTextArea matlab.ui.control.TextArea

        RightTabGroup matlab.ui.container.TabGroup
        DataTab matlab.ui.container.Tab
        VisualTab matlab.ui.container.Tab
        FeatureTab matlab.ui.container.Tab
        AnalysisTab matlab.ui.container.Tab
        DiagnosisTab matlab.ui.container.Tab

        DataGrid matlab.ui.container.GridLayout
        SummaryTable matlab.ui.control.Table
        GuidedPreviewTable matlab.ui.control.Table
        FiberPreviewTable matlab.ui.control.Table

        VisualGrid matlab.ui.container.GridLayout
        SignalFieldDropDown matlab.ui.control.DropDown
        ConditionDropDown matlab.ui.control.DropDown
        FiberConditionListBox matlab.ui.control.ListBox
        TimeFreqMethodDropDown matlab.ui.control.DropDown
        FeatureNameDropDown matlab.ui.control.DropDown
        PlotAllButton matlab.ui.control.Button
        GWOverlayAxes matlab.ui.control.UIAxes
        ConditionMapAxes matlab.ui.control.UIAxes
        TimeFreqAxes matlab.ui.control.UIAxes
        FiberOverlayAxes matlab.ui.control.UIAxes
        DamageTrendAxes matlab.ui.control.UIAxes
        FeatureTrendAxes matlab.ui.control.UIAxes

        FeatureGrid matlab.ui.container.GridLayout
        FeatureTypeDropDown matlab.ui.control.DropDown
        PreviewFeatureButton matlab.ui.control.Button
        ExportFeatureButton matlab.ui.control.Button
        FeaturePreviewTable matlab.ui.control.Table
        FeatureInfoTextArea matlab.ui.control.TextArea

        AnalysisGrid matlab.ui.container.GridLayout
        PlotPCAButton matlab.ui.control.Button
        PlotTSNEButton matlab.ui.control.Button
        PlotCorrButton matlab.ui.control.Button
        PCAAxes matlab.ui.control.UIAxes
        TSNEAxes matlab.ui.control.UIAxes
        CorrAxes matlab.ui.control.UIAxes

        DiagnosisGrid matlab.ui.container.GridLayout
        AnomalyAxes matlab.ui.control.UIAxes
        ConfusionAxes matlab.ui.control.UIAxes
        ImportanceAxes matlab.ui.control.UIAxes
        DiagnosisMetricsTextArea matlab.ui.control.TextArea
    end

    properties (Access = private)
        ProjectRoot string = ""
        GuidedWaveDir string = ""
        FiberDir string = ""
        OutputDir string = ""

        Fs double = 12e6
        SignalLength double = 4000
        DefaultPathLabels cell = {'1-4','1-5','1-6','2-4','2-5','2-6','3-4','3-5','3-6'}
        StageEdges double = [-inf, 0, 5000, 50000, inf]
        StageNames string = ["Healthy", "Early", "Middle", "Late"]
        GuidedWavePattern char = 'F08*_offline.mat'
        GuidedWaveIgnore cell = {'SETUP.mat', 'allReceivedSignals.mat'}
        FiberPattern char = '*.txt'
        FiberIgnoreContains cell = {'FATIGUE', 'AE'}

        GuidedDataset table = table()
        FiberDataset table = table()
        GuidedFeat table = table()
        FiberFeat table = table()
        GuidedAgg table = table()
        FusedFeat table = table()
        DiagResult struct = struct()
        SetupInfo struct = struct()
    end

    methods (Access = private)

        function startupFcn(app)
            here = fileparts(mfilename('fullpath'));
            app.ProjectRoot = string(here);
            if isfolder(fullfile(here, '导波数据')) && isfolder(fullfile(here, '光纤数据'))
                app.GuidedWaveDir = string(fullfile(here, '导波数据'));
                app.FiberDir = string(fullfile(here, '光纤数据'));
            elseif isfolder(fullfile(fileparts(here), '导波数据')) && isfolder(fullfile(fileparts(here), '光纤数据'))
                app.ProjectRoot = string(fileparts(here));
                app.GuidedWaveDir = string(fullfile(fileparts(here), '导波数据'));
                app.FiberDir = string(fullfile(fileparts(here), '光纤数据'));
            else
                app.ProjectRoot = string(pwd);
                app.GuidedWaveDir = string(fullfile(app.ProjectRoot, '导波数据'));
                app.FiberDir = string(fullfile(app.ProjectRoot, '光纤数据'));
            end
            app.OutputDir = string(fullfile(app.ProjectRoot, 'outputs_app'));
            app.ensureFolder(app.OutputDir);
            app.updatePathFields();
            app.setIdleStatus();
            app.initializeSummaryTable();
            app.logMessage('平台已启动。先设置工程目录，再执行“导入导波 / 导入光纤 / 特征提取 / 诊断”。');
        end

        function updatePathFields(app)
            app.ProjectRootField.Value = char(app.ProjectRoot);
            app.GuidedWaveDirField.Value = char(app.GuidedWaveDir);
            app.FiberDirField.Value = char(app.FiberDir);
            app.OutputDirField.Value = char(app.OutputDir);
        end

        function setBusyStatus(app, txt)
            app.StatusLamp.Color = [1.0, 0.65, 0.1];
            app.StatusLabel.Text = txt;
            drawnow;
        end

        function setIdleStatus(app)
            app.StatusLamp.Color = [0.2, 0.7, 0.25];
            app.StatusLabel.Text = '就绪';
        end

        function setErrorStatus(app, txt)
            app.StatusLamp.Color = [0.9, 0.2, 0.2];
            app.StatusLabel.Text = txt;
        end

        function logMessage(app, msg)
            stamp = datestr(now, 'HH:MM:SS');
            old = app.LogTextArea.Value;
            if ischar(old)
                old = cellstr(old);
            end
            old = [old; {[stamp '  ' char(string(msg))]}]; %#ok<AGROW>
            app.LogTextArea.Value = old;
            drawnow;
        end

        function ensureFolder(~, p)
            if ~isfolder(p)
                mkdir(p);
            end
        end

        function onChooseProject(app, ~)
            p = uigetdir(char(app.ProjectRoot), '选择工程根目录');
            if isequal(p, 0)
                return;
            end
            app.ProjectRoot = string(p);
            gw = fullfile(p, '导波数据');
            fb = fullfile(p, '光纤数据');
            if isfolder(gw)
                app.GuidedWaveDir = string(gw);
            end
            if isfolder(fb)
                app.FiberDir = string(fb);
            end
            app.OutputDir = string(fullfile(p, 'outputs_app'));
            app.ensureFolder(app.OutputDir);
            app.updatePathFields();
            app.logMessage(['工程目录已更新：' p]);
        end

        function onChooseGW(app, ~)
            p = uigetdir(char(app.GuidedWaveDir), '选择导波数据目录');
            if isequal(p, 0)
                return;
            end
            app.GuidedWaveDir = string(p);
            app.updatePathFields();
            app.logMessage(['导波目录已更新：' p]);
        end

        function onChooseFiber(app, ~)
            p = uigetdir(char(app.FiberDir), '选择光纤数据目录');
            if isequal(p, 0)
                return;
            end
            app.FiberDir = string(p);
            app.updatePathFields();
            app.logMessage(['光纤目录已更新：' p]);
        end

        function onChooseOutput(app, ~)
            p = uigetdir(char(app.OutputDir), '选择输出目录');
            if isequal(p, 0)
                return;
            end
            app.OutputDir = string(p);
            app.ensureFolder(app.OutputDir);
            app.updatePathFields();
            app.logMessage(['输出目录已更新：' p]);
        end

        function importGuidedWaveButtonPushed(app, ~)
            try
                app.setBusyStatus('导入导波数据中');
                app.logMessage('开始导入导波数据...');
                app.GuidedDataset = app.buildGuidedDataset();
            catch ME
                app.handleException('导入导波数据失败', ME);
                return;
            end
            app.refreshUIAfterImport();
            app.logMessage(sprintf('导波数据导入完成：%d 行记录。', height(app.GuidedDataset)));
            app.setIdleStatus();
        end

        function importFiberButtonPushed(app, ~)
            try
                app.setBusyStatus('导入光纤数据中');
                app.logMessage('开始导入光纤数据...');
                app.FiberDataset = app.buildFiberDataset();
            catch ME
                app.handleException('导入光纤数据失败', ME);
                return;
            end
            app.refreshUIAfterImport();
            app.logMessage(sprintf('光纤数据导入完成：%d 个工况。', height(app.FiberDataset)));
            app.setIdleStatus();
        end

        function importAllButtonPushed(app, ~)
            try
                app.setBusyStatus('一键导入中');
                app.logMessage('开始一键导入导波 + 光纤数据...');
                app.GuidedDataset = app.buildGuidedDataset();
                app.FiberDataset = app.buildFiberDataset();
                app.refreshUIAfterImport();
                app.logMessage('一键导入完成。');
                app.setIdleStatus();
            catch ME
                app.handleException('一键导入失败', ME);
            end
        end

        function extractFeaturesButtonPushed(app, ~)
            try
                if isempty(app.GuidedDataset) || height(app.GuidedDataset) == 0
                    error('请先导入导波数据。');
                end
                if isempty(app.FiberDataset) || height(app.FiberDataset) == 0
                    error('请先导入光纤数据。');
                end
                app.setBusyStatus('特征提取中');
                app.logMessage('开始提取导波 / 光纤 / 融合特征...');
                [app.GuidedFeat, app.FiberFeat, app.GuidedAgg, app.FusedFeat] = app.extractAllFeatures();
                app.updateFeaturePreview();
                app.updateVisualSelectors();
                app.saveWorkspace();
                app.logMessage(sprintf('特征提取完成：导波 %d 行，光纤 %d 行，融合 %d 行。', ...
                    height(app.GuidedFeat), height(app.FiberFeat), height(app.FusedFeat)));
                app.setIdleStatus();
            catch ME
                app.handleException('特征提取失败', ME);
            end
        end

        function refreshAnalysisButtonPushed(app, ~)
            try
                if isempty(app.FusedFeat) || height(app.FusedFeat) == 0
                    error('请先执行特征提取。');
                end
                app.setBusyStatus('更新分析图中');
                app.plotPCA();
                app.plotTSNE();
                app.plotCorrelationHeatmap();
                app.setIdleStatus();
                app.logMessage('特征分析图已刷新。');
            catch ME
                app.handleException('更新分析图失败', ME);
            end
        end

        function runDiagnosisButtonPushed(app, ~)
            try
                if isempty(app.FusedFeat) || height(app.FusedFeat) == 0
                    error('请先执行特征提取。');
                end
                app.setBusyStatus('诊断建模中');
                app.logMessage('开始进行故障诊断建模...');
                app.DiagResult = app.runDiagnosisModel();
                app.plotDiagnosisResults();
                app.saveWorkspace();
                app.logMessage('故障诊断完成。');
                app.setIdleStatus();
            catch ME
                app.handleException('故障诊断失败', ME);
            end
        end

        function saveWorkspaceButtonPushed(app, ~)
            try
                app.saveWorkspace();
                app.logMessage('当前工作区数据已保存。');
            catch ME
                app.handleException('保存工作区失败', ME);
            end
        end

        function refreshUIAfterImport(app)
            app.initializeSummaryTable();
            app.updatePreviewTables();
            app.updateVisualSelectors();
        end

        function initializeSummaryTable(app)
            T = table( ...
                {'导波数据'; '光纤数据'; '导波特征'; '光纤特征'; '融合特征'}, ...
                [heightSafe(app.GuidedDataset); heightSafe(app.FiberDataset); heightSafe(app.GuidedFeat); heightSafe(app.FiberFeat); heightSafe(app.FusedFeat)], ...
                [uniqueCount(app.GuidedDataset, 'ConditionName'); uniqueCount(app.FiberDataset, 'ConditionName'); uniqueCount(app.GuidedFeat, 'ConditionName'); uniqueCount(app.FiberFeat, 'ConditionName'); uniqueCount(app.FusedFeat, 'ConditionName')], ...
                {['信号字段数=' num2str(signalFieldCount(app.GuidedDataset))]; ['平均样本数=' num2str(sampleCountMean(app.FiberDataset))]; ''; ''; ''}, ...
                'VariableNames', {'模块', '文件或记录数', '工况数', '补充说明'});
            app.setUITableFromTable(app.SummaryTable, T);
        end

        function updatePreviewTables(app)
            if ~isempty(app.GuidedDataset) && height(app.GuidedDataset) > 0
                vars = {'ConditionName','CycleNum','SignalField','SignalId','FrequencyKHz','PathLabel','SignalEnergy','PeakAbs','RMSValue'};
                T = app.GuidedDataset(1:min(20,height(app.GuidedDataset)), vars);
                app.setUITableFromTable(app.GuidedPreviewTable, T);
            else
                app.GuidedPreviewTable.Data = {};
            end

            if ~isempty(app.FiberDataset) && height(app.FiberDataset) > 0
                vars = {'ConditionName','CycleNum','FileName','ProfileEnergy','ProfileRange','ProfileMaxAbs'};
                T = app.FiberDataset(1:min(20,height(app.FiberDataset)), vars);
                app.setUITableFromTable(app.FiberPreviewTable, T);
            else
                app.FiberPreviewTable.Data = {};
            end
        end

        function updateFeaturePreview(app)
            choice = string(app.FeatureTypeDropDown.Value);
            switch choice
                case "导波逐信号特征"
                    T = app.GuidedFeat;
                case "光纤逐工况特征"
                    T = app.FiberFeat;
                case "导波工况聚合特征"
                    T = app.GuidedAgg;
                otherwise
                    T = app.FusedFeat;
            end

            if isempty(T) || height(T) == 0
                app.FeaturePreviewTable.Data = {};
                app.FeaturePreviewTable.ColumnName = {};
                app.FeatureInfoTextArea.Value = {'当前没有特征数据。'};
                return;
            end

            Tshow = T(1:min(30,height(T)), :);
            app.setUITableFromTable(app.FeaturePreviewTable, Tshow);
            info = {
                ['当前表：' char(choice)], ...
                ['行数：' num2str(height(T))], ...
                ['列数：' num2str(width(T))], ...
                ['数值特征列：' num2str(numNumericCols(T))]
            };
            app.FeatureInfoTextArea.Value = info;
            app.updateFeatureDropdownByTable();
        end

        function previewFeatureButtonPushed(app, ~)
            app.updateFeaturePreview();
        end

        function exportFeatureButtonPushed(app, ~)
            try
                if isempty(app.FusedFeat) || height(app.FusedFeat) == 0
                    error('没有可导出的融合特征。');
                end
                outCsv = fullfile(app.OutputDir, 'fused_condition_features.csv');
                writetable(app.FusedFeat, outCsv);
                app.logMessage(['融合特征 CSV 已导出：' outCsv]);
            catch ME
                app.handleException('导出特征失败', ME);
            end
        end

        function plotAllButtonPushed(app, ~)
            try
                if isempty(app.GuidedDataset) || isempty(app.FiberDataset)
                    error('请先完成数据导入。');
                end
                app.setBusyStatus('绘制可视化图中');
                app.plotGuidedWaveOverlay();
                app.plotConditionMap();
                app.plotTimeFrequency();
                app.plotFiberOverlay();
                app.plotDamageTrend();
                app.plotFeatureTrend();
                app.setIdleStatus();
                app.logMessage('可视化图已更新。');
            catch ME
                app.handleException('绘图失败', ME);
            end
        end

        function onSignalSelectionChanged(app, ~)
            if isempty(app.GuidedDataset)
                return;
            end
            try
                app.plotGuidedWaveOverlay();
                app.plotConditionMap();
                app.plotTimeFrequency();
                app.plotDamageTrend();
                app.plotFeatureTrend();
            catch
            end
        end

        function onFeatureTypeChanged(app, ~)
            app.updateFeaturePreview();
        end

        function updateVisualSelectors(app)
            if ~isempty(app.GuidedDataset) && height(app.GuidedDataset) > 0
                fields = unique(string(app.GuidedDataset.SignalField), 'stable');
                app.SignalFieldDropDown.Items = cellstr(fields);
                if ~isempty(fields)
                    if ~ismember(app.SignalFieldDropDown.Value, app.SignalFieldDropDown.Items)
                        app.SignalFieldDropDown.Value = char(fields(1));
                    end
                end
                conds = unique(string(app.GuidedDataset.ConditionName), 'stable');
                app.ConditionDropDown.Items = cellstr(conds);
                if ~isempty(conds)
                    if ~ismember(app.ConditionDropDown.Value, app.ConditionDropDown.Items)
                        app.ConditionDropDown.Value = char(conds(min(1,numel(conds))));
                    end
                end
            end

            if ~isempty(app.FiberDataset) && height(app.FiberDataset) > 0
                fconds = unique(string(app.FiberDataset.ConditionName), 'stable');
                app.FiberConditionListBox.Items = cellstr(fconds);
                if numel(fconds) >= 4
                    app.FiberConditionListBox.Value = cellstr(fconds(1:min(4,numel(fconds))));
                else
                    app.FiberConditionListBox.Value = cellstr(fconds);
                end
            end
            app.updateFeatureDropdownByTable();
        end

        function updateFeatureDropdownByTable(app)
            if ~isempty(app.GuidedFeat) && height(app.GuidedFeat) > 0
                vars = app.GuidedFeat.Properties.VariableNames;
                keep = startsWith(vars, 'GW_');
                items = vars(keep);
                if isempty(items)
                    items = {'GW_DamageIndex'};
                end
            elseif ~isempty(app.FusedFeat) && height(app.FusedFeat) > 0
                vars = app.FusedFeat.Properties.VariableNames;
                items = vars(cellfun(@(x) isnumeric(app.FusedFeat.(x)), vars));
            else
                items = {'GW_DamageIndex'};
            end
            app.FeatureNameDropDown.Items = items;
            if ~isempty(items)
                app.FeatureNameDropDown.Value = items{1};
            end
        end

        function saveWorkspace(app)
            app.ensureFolder(app.OutputDir);
            if ~isempty(app.GuidedDataset) && height(app.GuidedDataset) > 0
                dataset = app.GuidedDataset; %#ok<NASGU>
                save(fullfile(app.OutputDir, 'dataset_guidedwave.mat'), 'dataset', '-v7.3');
            end
            if ~isempty(app.FiberDataset) && height(app.FiberDataset) > 0
                dataset = app.FiberDataset; %#ok<NASGU>
                save(fullfile(app.OutputDir, 'dataset_fiber.mat'), 'dataset', '-v7.3');
            end
            if ~isempty(app.FusedFeat) && height(app.FusedFeat) > 0
                guidedFeat = app.GuidedFeat; %#ok<NASGU>
                fiberFeat = app.FiberFeat; %#ok<NASGU>
                guidedAgg = app.GuidedAgg; %#ok<NASGU>
                fusedFeat = app.FusedFeat; %#ok<NASGU>
                save(fullfile(app.OutputDir, 'feature_tables.mat'), 'guidedFeat', 'fiberFeat', 'guidedAgg', 'fusedFeat', '-v7.3');
            end
            if ~isempty(fieldnames(app.DiagResult))
                result = app.DiagResult; %#ok<NASGU>
                save(fullfile(app.OutputDir, 'fault_diagnosis_model.mat'), 'result', '-v7.3');
            end
        end

        function plotGuidedWaveOverlay(app)
            cla(app.GWOverlayAxes);
            if isempty(app.GuidedDataset) || height(app.GuidedDataset) == 0
                return;
            end
            fieldName = string(app.SignalFieldDropDown.Value);
            T = app.GuidedDataset(app.GuidedDataset.SignalField == fieldName, :);
            if isempty(T)
                return;
            end
            T = sortrows(T, 'CycleNum');
            hold(app.GWOverlayAxes, 'on');
            for i = 1:height(T)
                plot(app.GWOverlayAxes, T.TimeAxisUs{i}, T.ProcSignal{i}, 'LineWidth', 1.0, ...
                    'DisplayName', char(T.ConditionName(i)));
            end
            hold(app.GWOverlayAxes, 'off');
            grid(app.GWOverlayAxes, 'on');
            xlabel(app.GWOverlayAxes, 'Time (\mus)');
            ylabel(app.GWOverlayAxes, 'Amplitude');
            title(app.GWOverlayAxes, ['导波波形叠加 - ' char(fieldName)]);
            legend(app.GWOverlayAxes, 'Location', 'best');
        end

        function plotConditionMap(app)
            cla(app.ConditionMapAxes);
            if isempty(app.GuidedDataset) || height(app.GuidedDataset) == 0
                return;
            end
            fieldName = string(app.SignalFieldDropDown.Value);
            T = app.GuidedDataset(app.GuidedDataset.SignalField == fieldName, :);
            if isempty(T)
                return;
            end
            T = sortrows(T, 'CycleNum');
            M = cell2mat(cellfun(@(x) x(:).', T.ProcSignal, 'UniformOutput', false));
            tUs = T.TimeAxisUs{1};
            imagesc(app.ConditionMapAxes, tUs, T.CycleNum, M);
            axis(app.ConditionMapAxes, 'tight');
            xlabel(app.ConditionMapAxes, 'Time (\mus)');
            ylabel(app.ConditionMapAxes, 'Fatigue cycles');
            title(app.ConditionMapAxes, ['工况-时间二维图 - ' char(fieldName)]);
            colorbar(app.ConditionMapAxes);
        end

        function plotTimeFrequency(app)
            cla(app.TimeFreqAxes);
            if isempty(app.GuidedDataset) || height(app.GuidedDataset) == 0
                return;
            end
            fieldName = string(app.SignalFieldDropDown.Value);
            condName = string(app.ConditionDropDown.Value);
            mask = app.GuidedDataset.SignalField == fieldName & app.GuidedDataset.ConditionName == condName;
            if ~any(mask)
                return;
            end
            row = app.GuidedDataset(find(mask, 1, 'first'), :);
            x = row.ProcSignal{1};
            fs = app.Fs;
            method = lower(string(app.TimeFreqMethodDropDown.Value));

            if method == "cwt" && exist('cwt', 'file') == 2
                [wt, f] = cwt(x, fs);
                imagesc(app.TimeFreqAxes, row.TimeAxisUs{1}, f/1e3, abs(wt));
                axis(app.TimeFreqAxes, 'xy');
                xlabel(app.TimeFreqAxes, 'Time (\mus)');
                ylabel(app.TimeFreqAxes, 'Frequency (kHz)');
                title(app.TimeFreqAxes, ['CWT - ' char(condName) ' - ' char(fieldName)]);
                colorbar(app.TimeFreqAxes);
            elseif exist('spectrogram', 'file') == 2
                [S, F, T] = spectrogram(x, 256, 220, 512, fs, 'yaxis');
                P = 20 * log10(abs(S) + eps);
                imagesc(app.TimeFreqAxes, T*1e6, F/1e3, P);
                axis(app.TimeFreqAxes, 'xy');
                xlabel(app.TimeFreqAxes, 'Time (\mus)');
                ylabel(app.TimeFreqAxes, 'Frequency (kHz)');
                title(app.TimeFreqAxes, ['Spectrogram - ' char(condName) ' - ' char(fieldName)]);
                colorbar(app.TimeFreqAxes);
            else
                n = numel(x);
                Y = abs(fft(x));
                f = (0:floor(n/2)) * fs / n / 1e3;
                plot(app.TimeFreqAxes, f, Y(1:numel(f)), 'LineWidth', 1.1);
                grid(app.TimeFreqAxes, 'on');
                xlabel(app.TimeFreqAxes, 'Frequency (kHz)');
                ylabel(app.TimeFreqAxes, 'Amplitude');
                title(app.TimeFreqAxes, ['频谱图 - ' char(condName) ' - ' char(fieldName)]);
            end
        end

        function plotFiberOverlay(app)
            cla(app.FiberOverlayAxes);
            if isempty(app.FiberDataset) || height(app.FiberDataset) == 0
                return;
            end
            values = app.FiberConditionListBox.Value;
            if ischar(values)
                values = {values};
            end
            hold(app.FiberOverlayAxes, 'on');
            for i = 1:numel(values)
                condName = string(values{i});
                mask = app.FiberDataset.ConditionName == condName;
                if any(mask)
                    row = app.FiberDataset(find(mask,1,'first'), :);
                    plot(app.FiberOverlayAxes, row.XAxisProc{1}, row.ProcProfile{1}, 'LineWidth', 1.1, ...
                        'DisplayName', char(condName));
                end
            end
            hold(app.FiberOverlayAxes, 'off');
            grid(app.FiberOverlayAxes, 'on');
            xlabel(app.FiberOverlayAxes, 'Fiber axis');
            ylabel(app.FiberOverlayAxes, 'Profile value');
            title(app.FiberOverlayAxes, '光纤剖面叠加');
            legend(app.FiberOverlayAxes, 'Location', 'best');
        end

        function plotDamageTrend(app)
            cla(app.DamageTrendAxes);
            if isempty(app.GuidedFeat) || height(app.GuidedFeat) == 0
                title(app.DamageTrendAxes, '导波损伤趋势（请先提取特征）');
                return;
            end
            T = app.aggregateGuidedByCycleAndPath(app.GuidedFeat);
            paths = unique(string(T.PathLabel), 'stable');
            hold(app.DamageTrendAxes, 'on');
            for i = 1:numel(paths)
                sub = T(T.PathLabel == paths(i), :);
                plot(app.DamageTrendAxes, sub.CycleNum, sub.MeanDamage, '-o', 'LineWidth', 1.1, ...
                    'DisplayName', char(paths(i)));
            end
            hold(app.DamageTrendAxes, 'off');
            grid(app.DamageTrendAxes, 'on');
            set(app.DamageTrendAxes, 'XScale', 'log');
            xlabel(app.DamageTrendAxes, 'Fatigue cycles');
            ylabel(app.DamageTrendAxes, 'Mean damage index');
            title(app.DamageTrendAxes, '导波路径损伤趋势');
            legend(app.DamageTrendAxes, 'Location', 'eastoutside');
        end

        function plotFeatureTrend(app)
            cla(app.FeatureTrendAxes);
            if isempty(app.GuidedFeat) || height(app.GuidedFeat) == 0
                title(app.FeatureTrendAxes, '特征趋势（请先提取特征）');
                return;
            end
            featureName = char(string(app.FeatureNameDropDown.Value));
            fieldName = string(app.SignalFieldDropDown.Value);
            T = app.GuidedFeat(app.GuidedFeat.SignalField == fieldName, :);
            if isempty(T) || ~ismember(featureName, T.Properties.VariableNames)
                return;
            end
            T = sortrows(T, 'CycleNum');
            y = T.(featureName);
            plot(app.FeatureTrendAxes, T.CycleNum, y, '-o', 'LineWidth', 1.1);
            grid(app.FeatureTrendAxes, 'on');
            set(app.FeatureTrendAxes, 'XScale', 'log');
            xlabel(app.FeatureTrendAxes, 'Fatigue cycles');
            ylabel(app.FeatureTrendAxes, strrep(featureName, '_', '\_'));
            title(app.FeatureTrendAxes, ['特征趋势 - ' featureName ' - ' char(fieldName)]);
        end

        function plotPCA(app)
            cla(app.PCAAxes);
            if isempty(app.FusedFeat) || height(app.FusedFeat) == 0
                return;
            end
            [X, stageLabel] = app.getFusionMatrixForAnalysis();
            if size(X,1) < 2
                return;
            end
            if exist('pca', 'file') == 2
                [~, score, ~, ~, explained] = pca(X);
            else
                X0 = X - mean(X,1);
                [~, S, V] = svd(X0, 'econ');
                score = X0 * V;
                latent = diag(S).^2;
                explained = latent / max(sum(latent), eps) * 100;
            end
            if size(score,2) < 2
                score(:,2) = 0;
                explained(2,1) = 0;
            end
            app.scatterByGroup(app.PCAAxes, score(:,1), score(:,2), stageLabel);
            xlabel(app.PCAAxes, sprintf('PC1 (%.1f%%)', explained(1)));
            ylabel(app.PCAAxes, sprintf('PC2 (%.1f%%)', explained(2)));
            title(app.PCAAxes, '融合特征 PCA');
            grid(app.PCAAxes, 'on');
        end

        function plotTSNE(app)
            cla(app.TSNEAxes);
            if isempty(app.FusedFeat) || height(app.FusedFeat) == 0
                return;
            end
            [X, stageLabel] = app.getFusionMatrixForAnalysis();
            if size(X,1) < 4
                title(app.TSNEAxes, 't-SNE 样本数不足');
                return;
            end
            if exist('tsne', 'file') == 2
                Y = tsne(X, 'NumDimensions', 2, 'Perplexity', min(5, size(X,1)-1));
                app.scatterByGroup(app.TSNEAxes, Y(:,1), Y(:,2), stageLabel);
                xlabel(app.TSNEAxes, 't-SNE 1');
                ylabel(app.TSNEAxes, 't-SNE 2');
                title(app.TSNEAxes, '融合特征 t-SNE');
                grid(app.TSNEAxes, 'on');
            else
                text(app.TSNEAxes, 0.1, 0.5, '当前环境没有 tsne 函数', 'FontSize', 12);
                axis(app.TSNEAxes, 'off');
            end
        end

        function plotCorrelationHeatmap(app)
            cla(app.CorrAxes);
            if isempty(app.FusedFeat) || height(app.FusedFeat) == 0
                return;
            end
            [X, featureNames] = app.selectNumericFeatureColumns(app.FusedFeat, {'CycleNum'});
            X = app.fillmissingByMedian(X);
            if isempty(X)
                return;
            end
            varMask = std(X,0,1) > 0;
            X = X(:, varMask);
            featureNames = featureNames(varMask);
            if isempty(X)
                return;
            end
            if size(X,2) > 20
                X = X(:,1:20);
                featureNames = featureNames(1:20);
            end
            C = corrcoef(X);
            imagesc(app.CorrAxes, C);
            colormap(app.CorrAxes, parula);
            colorbar(app.CorrAxes);
            axis(app.CorrAxes, 'tight');
            title(app.CorrAxes, '特征相关性热图（前20列）');
            app.CorrAxes.XTick = 1:numel(featureNames);
            app.CorrAxes.YTick = 1:numel(featureNames);
            app.CorrAxes.XTickLabel = featureNames;
            app.CorrAxes.YTickLabel = featureNames;
            app.CorrAxes.XTickLabelRotation = 45;
        end

        function result = runDiagnosisModel(app)
            result = struct();
            [X, featureNames] = app.selectNumericFeatureColumns(app.FusedFeat, {'CycleNum'});
            X = app.fillmissingByMedian(X);
            validMask = all(isfinite(X), 2);
            X = X(validMask, :);
            T = app.FusedFeat(validMask, :);
            Y = categorical(T.StageLabel);
            varMask = std(X,0,1) > 0;
            X = X(:, varMask);
            featureNames = featureNames(varMask);
            X = app.zscoreSafe(X);

            result.featureNames = featureNames;
            result.sampleTable = T;

            healthyMask = T.CycleNum == min(T.CycleNum);
            if any(healthyMask)
                mu0 = mean(X(healthyMask,:), 1);
            else
                mu0 = mean(X, 1);
            end
            anomalyScore = sqrt(sum((X - mu0).^2, 2));
            result.anomalyScore = anomalyScore;
            result.yTrue = Y;

            if exist('fitcensemble', 'file') == 2 && exist('cvpartition', 'file') == 2
                classNames = categories(Y);
                classCounts = countcats(Y);
                minCount = min(classCounts);
                if numel(classNames) >= 2 && minCount >= 2 && size(X,1) >= 8
                    K = min(5, minCount);
                    cvp = cvpartition(Y, 'KFold', K);
                    mdl = fitcensemble(X, Y, 'Method', 'Bag', 'NumLearningCycles', 100);
                    cvMdl = crossval(mdl, 'CVPartition', cvp);
                    yPred = kfoldPredict(cvMdl);
                    conf = confusionmat(Y, yPred);
                    acc = mean(yPred == Y);
                    result.model = mdl;
                    result.cvModel = cvMdl;
                    result.yPred = yPred;
                    result.confMat = conf;
                    result.accuracy = acc;
                    if exist('predictorImportance', 'file') == 2
                        result.importance = predictorImportance(mdl);
                    else
                        result.importance = zeros(1, numel(featureNames));
                    end
                else
                    result.model = [];
                    result.cvModel = [];
                    result.yPred = categorical(strings(size(Y)));
                    result.confMat = [];
                    result.accuracy = NaN;
                    result.importance = zeros(1, numel(featureNames));
                end
            else
                result.model = [];
                result.cvModel = [];
                result.yPred = categorical(strings(size(Y)));
                result.confMat = [];
                result.accuracy = NaN;
                result.importance = zeros(1, numel(featureNames));
            end
        end

        function plotDiagnosisResults(app)
            cla(app.AnomalyAxes);
            cla(app.ConfusionAxes);
            cla(app.ImportanceAxes);
            if isempty(fieldnames(app.DiagResult))
                return;
            end
            T = app.DiagResult.sampleTable;
            Y = categorical(T.StageLabel);
            scatter(app.AnomalyAxes, T.CycleNum, app.DiagResult.anomalyScore, 60, double(Y), 'filled');
            set(app.AnomalyAxes, 'XScale', 'log');
            grid(app.AnomalyAxes, 'on');
            xlabel(app.AnomalyAxes, 'Fatigue cycles');
            ylabel(app.AnomalyAxes, 'Anomaly score');
            title(app.AnomalyAxes, '损伤异常度评分');

            if ~isempty(app.DiagResult.confMat)
                imagesc(app.ConfusionAxes, app.DiagResult.confMat);
                colormap(app.ConfusionAxes, parula);
                colorbar(app.ConfusionAxes);
                classes = categories(app.DiagResult.yTrue);
                app.ConfusionAxes.XTick = 1:numel(classes);
                app.ConfusionAxes.YTick = 1:numel(classes);
                app.ConfusionAxes.XTickLabel = classes;
                app.ConfusionAxes.YTickLabel = classes;
                xlabel(app.ConfusionAxes, 'Predicted');
                ylabel(app.ConfusionAxes, 'True');
                title(app.ConfusionAxes, sprintf('混淆矩阵 - Accuracy %.2f%%', app.DiagResult.accuracy*100));
            else
                text(app.ConfusionAxes, 0.1, 0.5, '当前样本数或工具箱不足，已跳过监督分类', 'FontSize', 12);
                axis(app.ConfusionAxes, 'off');
            end

            imp = app.DiagResult.importance;
            fns = app.DiagResult.featureNames;
            if ~isempty(imp)
                [impSort, idx] = sort(imp, 'descend');
                topN = min(12, numel(idx));
                bar(app.ImportanceAxes, impSort(1:topN));
                app.ImportanceAxes.XTick = 1:topN;
                app.ImportanceAxes.XTickLabel = cellstr(fns(idx(1:topN)));
                app.ImportanceAxes.XTickLabelRotation = 45;
                ylabel(app.ImportanceAxes, 'Importance');
                title(app.ImportanceAxes, 'Top 特征重要性');
                grid(app.ImportanceAxes, 'on');
            end

            lines = {
                ['样本数：' num2str(height(T))], ...
                ['类别数：' num2str(numel(categories(Y)))], ...
                ['最小疲劳循环数：' num2str(min(T.CycleNum))], ...
                ['最大疲劳循环数：' num2str(max(T.CycleNum))]
            };
            if ~isempty(app.DiagResult.confMat)
                lines{end+1} = ['交叉验证准确率：' sprintf('%.2f%%', app.DiagResult.accuracy*100)]; %#ok<AGROW>
            else
                lines{end+1} = '监督分类：未执行 / 条件不足'; %#ok<AGROW>
            end
            app.DiagnosisMetricsTextArea.Value = lines;
        end

        function guidedDataset = buildGuidedDataset(app)
            if ~isfolder(app.GuidedWaveDir)
                error('未找到导波数据目录：%s', app.GuidedWaveDir);
            end
            files = dir(fullfile(app.GuidedWaveDir, app.GuidedWavePattern));
            if isempty(files)
                error('导波目录下未找到 MAT 文件。');
            end
            keep = true(numel(files), 1);
            for i = 1:numel(files)
                if ismember(files(i).name, app.GuidedWaveIgnore)
                    keep(i) = false;
                end
            end
            files = files(keep);
            setupFile = fullfile(app.GuidedWaveDir, 'SETUP.mat');
            app.SetupInfo = app.loadSetupInfo(setupFile);

            rows = {};
            rowCount = 0;
            for k = 1:numel(files)
                filePath = fullfile(files(k).folder, files(k).name);
                app.logMessage(['导波读取：' files(k).name]);
                conditionName = app.parseConditionFromFilename(files(k).name);
                cycleNum = app.parseCycleNumber(conditionName);
                condStruct = app.loadConditionStruct(filePath);
                signalFields = app.getSignalFields(condStruct);
                for i = 1:numel(signalFields)
                    fieldName = signalFields{i};
                    meta = app.parseSignalFieldName(fieldName);
                    rawSignal = double(condStruct.(fieldName));
                    rawSignal = rawSignal(:).';
                    proc = app.preprocessGuidedWave(rawSignal, meta.frequencyKHz);
                    pathLabel = app.inferPathLabel(meta.signalId);
                    rowCount = rowCount + 1;
                    rows(rowCount,:) = { ...
                        string(conditionName), double(cycleNum), string(files(k).name), string(filePath), ...
                        string(fieldName), double(meta.signalId), double(meta.frequencyKHz), string(pathLabel), ...
                        {rawSignal}, {proc.signal}, {proc.envelope}, {proc.timeAxisUs}, ...
                        double(proc.energy), double(proc.peakAbs), double(proc.rmsValue)};
                end
            end
            guidedDataset = cell2table(rows, 'VariableNames', { ...
                'ConditionName','CycleNum','FileName','FilePath', ...
                'SignalField','SignalId','FrequencyKHz','PathLabel', ...
                'RawSignal','ProcSignal','Envelope','TimeAxisUs', ...
                'SignalEnergy','PeakAbs','RMSValue'});
            guidedDataset = sortrows(guidedDataset, {'CycleNum','SignalId','FrequencyKHz'});
        end

        function fiberDataset = buildFiberDataset(app)
            if ~isfolder(app.FiberDir)
                error('未找到光纤数据目录：%s', app.FiberDir);
            end
            files = dir(fullfile(app.FiberDir, app.FiberPattern));
            if isempty(files)
                error('光纤目录下未找到 TXT 文件。');
            end
            keep = true(numel(files),1);
            for i = 1:numel(files)
                upperName = upper(files(i).name);
                for j = 1:numel(app.FiberIgnoreContains)
                    if contains(upperName, upper(app.FiberIgnoreContains{j}))
                        keep(i) = false;
                    end
                end
            end
            files = files(keep);

            rows = {};
            rowCount = 0;
            for k = 1:numel(files)
                filePath = fullfile(files(k).folder, files(k).name);
                app.logMessage(['光纤读取：' files(k).name]);
                conditionName = app.parseConditionFromFilename(files(k).name);
                cycleNum = app.parseCycleNumber(conditionName);
                fiber = app.readFiberTxt(filePath);
                proc = app.preprocessFiberProfile(fiber.xRaw, fiber.yRaw);
                rowCount = rowCount + 1;
                rows(rowCount,:) = { ...
                    string(conditionName), double(cycleNum), string(files(k).name), string(filePath), ...
                    {fiber.xRaw}, {fiber.yRaw}, {proc.x}, {proc.profile}, {proc.gradient}, ...
                    double(proc.energy), double(proc.rangeValue), double(proc.maxAbs)};
            end
            fiberDataset = cell2table(rows, 'VariableNames', { ...
                'ConditionName','CycleNum','FileName','FilePath', ...
                'XAxis','RawProfile','XAxisProc','ProcProfile','Gradient', ...
                'ProfileEnergy','ProfileRange','ProfileMaxAbs'});
            fiberDataset = sortrows(fiberDataset, {'CycleNum'});
        end

        function [guidedFeat, fiberFeat, guidedAgg, fusedFeat] = extractAllFeatures(app)
            rows = {};
            rowCount = 0;
            for i = 1:height(app.GuidedDataset)
                baseline = app.findBaselineGuidedWave(app.GuidedDataset, app.GuidedDataset.SignalField(i));
                feat = app.computeGuidedWaveFeatures( ...
                    app.GuidedDataset.ProcSignal{i}, app.GuidedDataset.Envelope{i}, ...
                    app.GuidedDataset.FrequencyKHz(i), baseline);
                rowCount = rowCount + 1;
                rows(rowCount,:) = { ...
                    app.GuidedDataset.ConditionName(i), app.GuidedDataset.CycleNum(i), ...
                    app.GuidedDataset.SignalField(i), app.GuidedDataset.SignalId(i), ...
                    app.GuidedDataset.FrequencyKHz(i), app.GuidedDataset.PathLabel(i), ...
                    feat.PeakAbs, feat.RMS, feat.Energy, feat.PeakToPeak, feat.Std, ...
                    feat.Skewness, feat.Kurtosis, feat.CrestFactor, feat.EnvelopePeak, ...
                    feat.ArrivalIndex, feat.DominantFreqKHz, feat.SpectralCentroidKHz, ...
                    feat.CenterFreqDeviationKHz, feat.BaselineCorr, feat.BaselineRMSE, ...
                    feat.BaselineMAE, feat.DamageIndex};
            end
            guidedFeat = cell2table(rows, 'VariableNames', { ...
                'ConditionName','CycleNum','SignalField','SignalId','FrequencyKHz','PathLabel', ...
                'GW_PeakAbs','GW_RMS','GW_Energy','GW_PeakToPeak','GW_Std', ...
                'GW_Skewness','GW_Kurtosis','GW_CrestFactor','GW_EnvelopePeak', ...
                'GW_ArrivalIndex','GW_DominantFreqKHz','GW_SpectralCentroidKHz', ...
                'GW_CenterFreqDeviationKHz','GW_BaselineCorr','GW_BaselineRMSE', ...
                'GW_BaselineMAE','GW_DamageIndex'});
            guidedFeat.StageLabel = app.assignStageLabel(guidedFeat.CycleNum);

            guidedAgg = app.aggregateGuidedFeatures(guidedFeat);
            guidedAgg.StageLabel = app.assignStageLabel(guidedAgg.CycleNum);

            rows = {};
            rowCount = 0;
            baselineFiber = app.findBaselineFiber(app.FiberDataset);
            for i = 1:height(app.FiberDataset)
                feat = app.computeFiberFeatures( ...
                    app.FiberDataset.XAxisProc{i}, app.FiberDataset.ProcProfile{i}, ...
                    baselineFiber.x, baselineFiber.y);
                rowCount = rowCount + 1;
                rows(rowCount,:) = { ...
                    app.FiberDataset.ConditionName(i), app.FiberDataset.CycleNum(i), ...
                    feat.SampleCount, feat.Mean, feat.Std, feat.Min, feat.Max, feat.Range, ...
                    feat.MaxAbs, feat.RMSEnergy, feat.GradEnergy, feat.GradMaxAbs, ...
                    feat.PeakLocation, feat.BaselineCorr, feat.BaselineRMSE, ...
                    feat.BaselineMAE, feat.BaselineShiftMean};
            end
            fiberFeat = cell2table(rows, 'VariableNames', { ...
                'ConditionName','CycleNum', ...
                'FB_SampleCount','FB_Mean','FB_Std','FB_Min','FB_Max','FB_Range', ...
                'FB_MaxAbs','FB_RMSEnergy','FB_GradEnergy','FB_GradMaxAbs', ...
                'FB_PeakLocation','FB_BaselineCorr','FB_BaselineRMSE', ...
                'FB_BaselineMAE','FB_BaselineShiftMean'});
            fiberFeat.StageLabel = app.assignStageLabel(fiberFeat.CycleNum);

            fusedFeat = app.joinConditionTables(guidedAgg, fiberFeat);
            fusedFeat.StageLabel = app.assignStageLabel(fusedFeat.CycleNum);
        end

        function stage = assignStageLabel(app, cycleNum)
            stage = strings(numel(cycleNum),1);
            for i = 1:numel(cycleNum)
                idx = find(cycleNum(i) > app.StageEdges(1:end-1) & cycleNum(i) <= app.StageEdges(2:end), 1, 'first');
                if isempty(idx)
                    stage(i) = "Unknown";
                else
                    stage(i) = app.StageNames(idx);
                end
            end
        end

        function T = aggregateGuidedByCycleAndPath(~, guidedFeat)
            conds = unique(guidedFeat.CycleNum);
            paths = unique(string(guidedFeat.PathLabel), 'stable');
            rows = {};
            n = 0;
            for i = 1:numel(conds)
                for j = 1:numel(paths)
                    mask = guidedFeat.CycleNum == conds(i) & string(guidedFeat.PathLabel) == paths(j);
                    if any(mask)
                        n = n + 1;
                        rows(n,:) = {double(conds(i)), string(paths(j)), meanFinite(guidedFeat.GW_DamageIndex(mask))}; %#ok<AGROW>
                    end
                end
            end
            T = cell2table(rows, 'VariableNames', {'CycleNum','PathLabel','MeanDamage'});
        end

        function guidedAgg = aggregateGuidedFeatures(app, guidedFeat)
            conds = unique(guidedFeat.ConditionName, 'stable');
            numericVars = guidedFeat.Properties.VariableNames(startsWith(guidedFeat.Properties.VariableNames, 'GW_'));
            rows = cell(numel(conds), 2 + 2*numel(numericVars));
            names = [{'ConditionName','CycleNum'}, strcat('mean_', numericVars), strcat('max_', numericVars)];
            for i = 1:numel(conds)
                mask = guidedFeat.ConditionName == conds(i);
                rows{i,1} = string(conds(i));
                rows{i,2} = meanFinite(guidedFeat.CycleNum(mask));
                c = 2;
                for j = 1:numel(numericVars)
                    v = guidedFeat.(numericVars{j})(mask);
                    c = c + 1;
                    rows{i,c} = meanFinite(v);
                end
                for j = 1:numel(numericVars)
                    v = guidedFeat.(numericVars{j})(mask);
                    c = c + 1;
                    rows{i,c} = maxFinite(v);
                end
            end
            guidedAgg = cell2table(rows, 'VariableNames', names);
        end

        function fusedFeat = joinConditionTables(~, guidedAgg, fiberFeat)
            keepG = ~strcmp(guidedAgg.Properties.VariableNames, 'StageLabel');
            keepF = ~ismember(fiberFeat.Properties.VariableNames, {'ConditionName','CycleNum','StageLabel'});
            G = guidedAgg(:, keepG);
            F = fiberFeat(:, keepF);
            keysG = strcat(string(guidedAgg.ConditionName), "__", string(guidedAgg.CycleNum));
            keysF = strcat(string(fiberFeat.ConditionName), "__", string(fiberFeat.CycleNum));
            rows = cell(height(G), width(G) + width(F));
            names = [G.Properties.VariableNames, F.Properties.VariableNames];
            for i = 1:height(G)
                rows(i,1:width(G)) = table2cell(G(i,:));
                idx = find(keysF == keysG(i), 1, 'first');
                if isempty(idx)
                    filler = cell(1, width(F));
                    filler(:) = {NaN};
                    rows(i,width(G)+1:end) = filler;
                else
                    rows(i,width(G)+1:end) = table2cell(F(idx,:));
                end
            end
            fusedFeat = cell2table(rows, 'VariableNames', names);
        end

        function baselineSignal = findBaselineGuidedWave(~, dataset, signalField)
            sub = dataset(dataset.SignalField == string(signalField), :);
            if isempty(sub)
                baselineSignal = [];
                return;
            end
            row = sub(sub.ConditionName == "N0", :);
            if isempty(row)
                [~, idx] = min(sub.CycleNum);
                row = sub(idx,:);
            end
            baselineSignal = row.ProcSignal{1};
        end

        function baseline = findBaselineFiber(~, dataset)
            row = dataset(dataset.ConditionName == "N0", :);
            if isempty(row)
                [~, idx] = min(dataset.CycleNum);
                row = dataset(idx,:);
            end
            baseline.x = row.XAxisProc{1};
            baseline.y = row.ProcProfile{1};
        end

        function feat = computeGuidedWaveFeatures(app, signal, envelope, frequencyKHz, baselineSignal)
            x = double(signal(:));
            env = double(envelope(:));
            if isempty(x)
                feat = app.emptyGuidedFeatureStruct();
                return;
            end
            xValid = x(isfinite(x));
            envValid = env(isfinite(env));
            if isempty(xValid)
                feat = app.emptyGuidedFeatureStruct();
                return;
            end
            xFFT = x;
            xFFT(~isfinite(xFFT)) = 0;
            n = numel(xFFT);
            Y = abs(fft(xFFT));
            Y = Y(1:floor(n/2)+1);
            f = (0:numel(Y)-1).' * app.Fs / n;
            pow = Y.^2;
            feat = struct();
            feat.PeakAbs = max(abs(xValid));
            feat.RMS = sqrt(mean(xValid.^2));
            feat.Energy = sum(xValid.^2);
            feat.PeakToPeak = max(xValid) - min(xValid);
            feat.Std = std(xValid);
            feat.Skewness = skewness(xValid, 0);
            feat.Kurtosis = kurtosis(xValid, 0);
            feat.CrestFactor = feat.PeakAbs / max(feat.RMS, eps);
            if isempty(envValid)
                feat.EnvelopePeak = NaN;
                feat.ArrivalIndex = NaN;
            else
                feat.EnvelopePeak = max(envValid);
                idx = find(env >= 0.1 * feat.EnvelopePeak, 1, 'first');
                if isempty(idx)
                    idx = NaN;
                end
                feat.ArrivalIndex = idx;
            end
            [~, idxMax] = max(Y);
            feat.DominantFreqKHz = f(idxMax) / 1e3;
            feat.SpectralCentroidKHz = sum(f .* pow) / max(sum(pow), eps) / 1e3;
            feat.CenterFreqDeviationKHz = feat.DominantFreqKHz - frequencyKHz;
            if nargin < 5 || isempty(baselineSignal)
                feat.BaselineCorr = NaN;
                feat.BaselineRMSE = NaN;
                feat.BaselineMAE = NaN;
                feat.DamageIndex = NaN;
            else
                b = double(baselineSignal(:));
                L = min(numel(x), numel(b));
                x1 = x(1:L);
                b1 = b(1:L);
                mask = isfinite(x1) & isfinite(b1);
                x1 = x1(mask);
                b1 = b1(mask);
                if isempty(x1)
                    feat.BaselineCorr = NaN;
                    feat.BaselineRMSE = NaN;
                    feat.BaselineMAE = NaN;
                    feat.DamageIndex = NaN;
                else
                    feat.BaselineCorr = corrFinite(x1, b1);
                    d = x1 - b1;
                    feat.BaselineRMSE = sqrt(mean(d.^2));
                    feat.BaselineMAE = mean(abs(d));
                    feat.DamageIndex = 1 - feat.BaselineCorr;
                end
            end
        end

        function feat = emptyGuidedFeatureStruct(~)
            keys = {'PeakAbs','RMS','Energy','PeakToPeak','Std','Skewness','Kurtosis','CrestFactor', ...
                'EnvelopePeak','ArrivalIndex','DominantFreqKHz','SpectralCentroidKHz', ...
                'CenterFreqDeviationKHz','BaselineCorr','BaselineRMSE','BaselineMAE','DamageIndex'};
            feat = struct();
            for i = 1:numel(keys)
                feat.(keys{i}) = NaN;
            end
        end

        function feat = computeFiberFeatures(~, x, y, baselineX, baselineY)
            [x, y] = uniqueXY(x, y);
            feat = struct();
            feat.SampleCount = numel(y);
            if isempty(x) || isempty(y)
                feat = emptyFiberStruct(feat);
                return;
            end
            if numel(x) >= 2
                g = gradient(y, x);
            else
                g = NaN(size(y));
            end
            yv = y(isfinite(y));
            gv = g(isfinite(g));
            if isempty(yv)
                feat = emptyFiberStruct(feat);
                return;
            end
            feat.Mean = mean(yv);
            feat.Std = std(yv);
            feat.Min = min(yv);
            feat.Max = max(yv);
            feat.Range = feat.Max - feat.Min;
            feat.MaxAbs = max(abs(yv));
            feat.RMSEnergy = sqrt(mean(yv.^2));
            if isempty(gv)
                feat.GradEnergy = NaN;
                feat.GradMaxAbs = NaN;
            else
                feat.GradEnergy = sum(gv.^2);
                feat.GradMaxAbs = max(abs(gv));
            end
            tmp = abs(y);
            tmp(~isfinite(tmp)) = -inf;
            [~, idxMax] = max(tmp);
            if isempty(idxMax) || ~isfinite(tmp(idxMax))
                feat.PeakLocation = NaN;
            else
                feat.PeakLocation = x(idxMax);
            end
            if nargin < 5 || isempty(baselineY)
                feat.BaselineCorr = NaN;
                feat.BaselineRMSE = NaN;
                feat.BaselineMAE = NaN;
                feat.BaselineShiftMean = NaN;
            else
                [bx, by] = uniqueXY(baselineX, baselineY);
                if isempty(bx)
                    feat.BaselineCorr = NaN;
                    feat.BaselineRMSE = NaN;
                    feat.BaselineMAE = NaN;
                    feat.BaselineShiftMean = NaN;
                else
                    if numel(bx) == numel(x) && all(abs(bx(:) - x(:)) < 1e-12)
                        b = by(:);
                    elseif numel(bx) < 2
                        b = repmat(by(1), size(x));
                    else
                        b = interp1(bx(:), by(:), x(:), 'linear', 'extrap');
                    end
                    mask = isfinite(y) & isfinite(b);
                    y1 = y(mask);
                    b1 = b(mask);
                    if isempty(y1)
                        feat.BaselineCorr = NaN;
                        feat.BaselineRMSE = NaN;
                        feat.BaselineMAE = NaN;
                        feat.BaselineShiftMean = NaN;
                    else
                        feat.BaselineCorr = corrFinite(y1, b1);
                        d = y1 - b1;
                        feat.BaselineRMSE = sqrt(mean(d.^2));
                        feat.BaselineMAE = mean(abs(d));
                        feat.BaselineShiftMean = mean(d);
                    end
                end
            end
        end

        function proc = preprocessGuidedWave(app, rawSignal, frequencyKHz)
            x = double(rawSignal(:).');
            if isempty(x)
                proc = struct('signal', [], 'envelope', [], 'timeAxisUs', [], 'energy', NaN, 'peakAbs', NaN, 'rmsValue', NaN);
                return;
            end
            x = x - meanFinite(x);
            x = fillNanLinear(x(:)).';
            fc = frequencyKHz * 1e3;
            bw = max(fc * 0.35, 5e3);
            fl = max(1e3, fc - bw/2);
            fh = min(app.Fs/2*0.98, fc + bw/2);
            if exist('butter', 'file') == 2 && exist('filtfilt', 'file') == 2 && fh > fl && app.Fs > 2*fh
                [b, a] = butter(4, [fl fh] / (app.Fs/2), 'bandpass');
                xFilt = filtfilt(b, a, x);
            else
                xFilt = x;
            end
            if exist('hilbert', 'file') == 2
                env = abs(hilbert(xFilt));
            else
                env = abs(xFilt);
            end
            proc.signal = xFilt;
            proc.envelope = env;
            proc.timeAxisUs = (0:numel(xFilt)-1) / app.Fs * 1e6;
            xv = xFilt(isfinite(xFilt));
            proc.energy = sum(xv.^2);
            proc.peakAbs = max(abs(xv));
            proc.rmsValue = sqrt(mean(xv.^2));
        end

        function proc = preprocessFiberProfile(~, x, y)
            x = double(x(:));
            y = double(y(:));
            y = fillNanLinear(y);
            if numel(y) >= 5
                if exist('smoothdata', 'file') == 2
                    w1 = makeValidWindow(11, numel(y));
                    y = smoothdata(y, 'movmedian', w1);
                    y = smoothdata(y, 'movmean', max(3, min(w1, 9)));
                else
                    y = movingAverage(y, 7);
                end
            end
            if numel(x) >= 2
                g = gradient(y, x);
            else
                g = NaN(size(y));
            end
            if numel(g) >= 5
                if exist('smoothdata', 'file') == 2
                    g = smoothdata(g, 'movmean', makeValidWindow(9, numel(g)));
                else
                    g = movingAverage(g, 5);
                end
            end
            yv = y(isfinite(y));
            proc.x = x;
            proc.profile = y;
            proc.gradient = g;
            proc.energy = sum(yv.^2);
            proc.rangeValue = max(yv) - min(yv);
            proc.maxAbs = max(abs(yv));
        end

        function conditionStruct = loadConditionStruct(app, filePath)
            S = load(filePath);
            conditionStruct = app.searchStruct(S, 0);
            if isempty(conditionStruct)
                error('未能在 MAT 中识别导波信号结构体：%s', filePath);
            end
        end

        function out = searchStruct(app, S, depth)
            out = [];
            if depth > 3
                return;
            end
            if isstruct(S)
                if app.hasSignalFields(S)
                    out = S;
                    return;
                end
                fns = fieldnames(S);
                for i = 1:numel(fns)
                    value = S.(fns{i});
                    if isstruct(value)
                        out = app.searchStruct(value, depth + 1);
                        if ~isempty(out)
                            return;
                        end
                    end
                end
            end
        end

        function tf = hasSignalFields(~, S)
            if ~isstruct(S)
                tf = false;
                return;
            end
            fns = fieldnames(S);
            tf = any(~cellfun(@isempty, regexp(fns, '^s\d+_\d+k$', 'once')));
        end

        function signalFields = getSignalFields(app, conditionStruct)
            fns = fieldnames(conditionStruct);
            mask = ~cellfun(@isempty, regexp(fns, '^s\d+_\d+k$', 'once'));
            signalFields = fns(mask);
            ids = zeros(numel(signalFields),1);
            freqs = zeros(numel(signalFields),1);
            for i = 1:numel(signalFields)
                meta = app.parseSignalFieldName(signalFields{i});
                ids(i) = meta.signalId;
                freqs(i) = meta.frequencyKHz;
            end
            T = table(signalFields(:), ids, freqs, 'VariableNames', {'Field','SignalId','Freq'});
            T = sortrows(T, {'SignalId','Freq'});
            signalFields = T.Field;
        end

        function meta = parseSignalFieldName(~, fieldName)
            tok = regexp(char(fieldName), '^s(\d+)_(\d+)k$', 'tokens', 'once');
            if isempty(tok)
                error('无法解析字段名：%s', fieldName);
            end
            meta.signalId = str2double(tok{1});
            meta.frequencyKHz = str2double(tok{2});
        end

        function conditionName = parseConditionFromFilename(~, fileName)
            [~, baseName, ~] = fileparts(fileName);
            tok = regexp(baseName, '(N\d+)', 'tokens', 'once');
            if isempty(tok)
                conditionName = string(baseName);
            else
                conditionName = string(tok{1});
            end
        end

        function cycleNum = parseCycleNumber(~, inputText)
            tok = regexp(char(string(inputText)), 'N(\d+)', 'tokens', 'once');
            if isempty(tok)
                cycleNum = NaN;
            else
                cycleNum = str2double(tok{1});
            end
        end

        function setupInfo = loadSetupInfo(app, setupFile)
            setupInfo = struct();
            setupInfo.available = false;
            setupInfo.pathLabels = string(app.DefaultPathLabels);
            setupInfo.pathBySignalId = strings(99,1);
            for i = 1:99
                pathIdx = ceil(i / 11);
                pathIdx = min(max(pathIdx,1), numel(app.DefaultPathLabels));
                setupInfo.pathBySignalId(i) = string(app.DefaultPathLabels{pathIdx});
            end
            if ~isfile(setupFile)
                return;
            end
            try
                S = load(setupFile);
                paths = recursiveFindPathLabels(S);
                paths = unique(paths, 'stable');
                if numel(paths) >= 9
                    setupInfo.available = true;
                    setupInfo.pathLabels = paths(1:9);
                    for i = 1:99
                        pathIdx = ceil(i / 11);
                        pathIdx = min(max(pathIdx,1), numel(setupInfo.pathLabels));
                        setupInfo.pathBySignalId(i) = setupInfo.pathLabels(pathIdx);
                    end
                end
            catch
            end
        end

        function pathLabel = inferPathLabel(app, signalId)
            if isfield(app.SetupInfo, 'pathBySignalId') && signalId >= 1 && signalId <= numel(app.SetupInfo.pathBySignalId)
                pathLabel = string(app.SetupInfo.pathBySignalId(signalId));
            else
                pathIdx = ceil(signalId / 11);
                pathIdx = min(max(pathIdx,1), numel(app.DefaultPathLabels));
                pathLabel = string(app.DefaultPathLabels{pathIdx});
            end
        end

        function fiber = readFiberTxt(~, filePath)
            fiber = struct();
            M = [];
            try
                opts = detectImportOptions(filePath, 'FileType', 'text');
                T = readtable(filePath, opts);
                M = table2array(T);
            catch
                try
                    M = readmatrix(filePath);
                catch
                    raw = importdata(filePath);
                    if isstruct(raw) && isfield(raw, 'data') && ~isempty(raw.data)
                        M = raw.data;
                    elseif isnumeric(raw)
                        M = raw;
                    else
                        M = readNumericByTextscan(filePath);
                    end
                end
            end
            if isempty(M)
                M = readNumericByTextscan(filePath);
            end
            M = double(M);
            if isvector(M)
                y = M(:);
                x = (1:numel(y)).';
            else
                validCols = find(sum(isfinite(M),1) > max(5, round(0.5 * size(M,1))));
                M = M(:, validCols);
                M = M(any(isfinite(M),2), :);
                if isempty(M)
                    error('txt 未读取到有效数值列：%s', filePath);
                elseif size(M,2) == 1
                    y = M(:,1);
                    x = (1:numel(y)).';
                else
                    x = M(:,1);
                    y = M(:,end);
                end
            end
            keep = isfinite(x) & isfinite(y);
            x = x(keep);
            y = y(keep);
            fiber.xRaw = x(:);
            fiber.yRaw = y(:);
            fiber.n = numel(y);
        end

        function setUITableFromTable(~, uit, T)
            C = table2cell(T);

            for i = 1:numel(C)
                v = C{i};

                if isempty(v)
                    C{i} = '';

                elseif ischar(v) || isnumeric(v) || islogical(v)
                    % 这些类型 UITable 可以直接接受

                elseif isstring(v)
                    if isscalar(v)
                        C{i} = char(v);
                    else
                        try
                            C{i} = char(strjoin(cellstr(v(:)), ', '));
                        catch
                            C{i} = char(v(1));
                        end
                    end

                elseif iscategorical(v)
                    try
                        C{i} = char(cellstr(v));
                    catch
                        C{i} = char(string(v));
                    end

                elseif isa(v, 'datetime') || isa(v, 'duration')
                    try
                        C{i} = char(v);
                    catch
                        C{i} = char(string(v));
                    end

                else
                    % 兜底：其他类型统一转成字符，避免 UITable 报错
                    try
                        if iscell(v)
                            if isempty(v)
                                C{i} = '';
                            elseif isscalar(v)
                                vv = v{1};
                                if ischar(vv) || isnumeric(vv) || islogical(vv)
                                    C{i} = vv;
                                elseif isstring(vv)
                                    C{i} = char(vv);
                                else
                                    C{i} = strtrim(evalc('disp(vv)'));
                                end
                            else
                                C{i} = strtrim(evalc('disp(v)'));
                            end
                        else
                            C{i} = strtrim(evalc('disp(v)'));
                        end
                    catch
                        C{i} = '[unsupported]';
                    end
                end
            end

            uit.Data = C;
            uit.ColumnName = T.Properties.VariableNames;
        end

        function [X, featureNames] = selectNumericFeatureColumns(~, T, excludeNames)
            if nargin < 3
                excludeNames = {};
            end
            featureNames = strings(0,1);
            X = [];
            vars = T.Properties.VariableNames;
            for i = 1:numel(vars)
                if ismember(vars{i}, excludeNames)
                    continue;
                end
                val = T.(vars{i});
                if isnumeric(val)
                    featureNames(end+1,1) = string(vars{i}); %#ok<AGROW>
                    X(:,end+1) = double(val); %#ok<AGROW>
                end
            end
        end

        function X = fillmissingByMedian(~, X)
            for j = 1:size(X,2)
                col = X(:,j);
                fin = col(isfinite(col));
                if isempty(fin)
                    medv = 0;
                else
                    medv = median(fin);
                end
                col(~isfinite(col)) = medv;
                X(:,j) = col;
            end
        end

        function [X, stageLabel] = getFusionMatrixForAnalysis(app)
            [rawX, ~] = app.selectNumericFeatureColumns(app.FusedFeat, {'CycleNum'});
            rawX = app.fillmissingByMedian(rawX);
            varMask = std(rawX,0,1) > 0;
            X = rawX(:, varMask);
            if isempty(X)
                X = zeros(height(app.FusedFeat), 1);
            end
            X = app.zscoreSafe(X);
            stageLabel = categorical(app.FusedFeat.StageLabel);
        end

        function X = zscoreSafe(~, X)
            mu = mean(X, 1);
            sigma = std(X, 0, 1);
            sigma(sigma == 0) = 1;
            X = (X - mu) ./ sigma;
        end

        function scatterByGroup(~, ax, x, y, g)
            cla(ax);
            hold(ax, 'on');
            cg = categorical(g);
            G = categories(cg);
            for i = 1:numel(G)
                mask = cg == G{i};
                scatter(ax, x(mask), y(mask), 48, 'filled', 'DisplayName', char(G{i}));
            end
            hold(ax, 'off');
            legend(ax, 'Location', 'best');
        end

        function handleException(app, prefix, ME)
            app.setErrorStatus('出错');
            msg = [prefix '：' ME.message];
            app.logMessage(msg);
            try
                uialert(app.UIFigure, msg, prefix, 'Icon', 'error');
            catch
            end
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1500 860];
            app.UIFigure.Name = '导波-光纤故障诊断平台';

            app.MainGrid = uigridlayout(app.UIFigure, [1 2]);
            app.MainGrid.ColumnWidth = {320, '1x'};
            app.MainGrid.RowHeight = {'1x'};
            app.MainGrid.Padding = [8 8 8 8];
            app.MainGrid.ColumnSpacing = 8;

            app.LeftPanel = uipanel(app.MainGrid, 'Title', '控制区');
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftGrid = uigridlayout(app.LeftPanel, [22 1]);
            app.LeftGrid.RowHeight = {22,28,28,22,28,28,22,28,28,22,28,28,28,28,28,28,28,28,28,28,22, '1x'};
            app.LeftGrid.Padding = [8 8 8 8];

            uilabel(app.LeftGrid, 'Text', '工程目录');
            app.ProjectRootField = uieditfield(app.LeftGrid, 'text');
            app.ProjectRootField.Editable = 'off';
            app.ChooseProjectButton = uibutton(app.LeftGrid, 'push', 'Text', '选择工程目录');
            app.ChooseProjectButton.ButtonPushedFcn = createCallbackFcn(app, @onChooseProject, true);

            uilabel(app.LeftGrid, 'Text', '导波目录');
            app.GuidedWaveDirField = uieditfield(app.LeftGrid, 'text');
            app.GuidedWaveDirField.Editable = 'off';
            app.ChooseGWButton = uibutton(app.LeftGrid, 'push', 'Text', '选择导波目录');
            app.ChooseGWButton.ButtonPushedFcn = createCallbackFcn(app, @onChooseGW, true);

            uilabel(app.LeftGrid, 'Text', '光纤目录');
            app.FiberDirField = uieditfield(app.LeftGrid, 'text');
            app.FiberDirField.Editable = 'off';
            app.ChooseFiberButton = uibutton(app.LeftGrid, 'push', 'Text', '选择光纤目录');
            app.ChooseFiberButton.ButtonPushedFcn = createCallbackFcn(app, @onChooseFiber, true);

            uilabel(app.LeftGrid, 'Text', '输出目录');
            app.OutputDirField = uieditfield(app.LeftGrid, 'text');
            app.OutputDirField.Editable = 'off';
            app.ChooseOutputButton = uibutton(app.LeftGrid, 'push', 'Text', '选择输出目录');
            app.ChooseOutputButton.ButtonPushedFcn = createCallbackFcn(app, @onChooseOutput, true);

            app.ImportGWButton = uibutton(app.LeftGrid, 'push', 'Text', '1. 导入导波数据');
            app.ImportGWButton.ButtonPushedFcn = createCallbackFcn(app, @importGuidedWaveButtonPushed, true);
            app.ImportFiberButton = uibutton(app.LeftGrid, 'push', 'Text', '2. 导入光纤数据');
            app.ImportFiberButton.ButtonPushedFcn = createCallbackFcn(app, @importFiberButtonPushed, true);
            app.ImportAllButton = uibutton(app.LeftGrid, 'push', 'Text', '3. 一键导入');
            app.ImportAllButton.ButtonPushedFcn = createCallbackFcn(app, @importAllButtonPushed, true);
            app.ExtractFeaturesButton = uibutton(app.LeftGrid, 'push', 'Text', '4. 特征提取');
            app.ExtractFeaturesButton.ButtonPushedFcn = createCallbackFcn(app, @extractFeaturesButtonPushed, true);
            app.RefreshAnalysisButton = uibutton(app.LeftGrid, 'push', 'Text', '5. 刷新分析图');
            app.RefreshAnalysisButton.ButtonPushedFcn = createCallbackFcn(app, @refreshAnalysisButtonPushed, true);
            app.RunDiagnosisButton = uibutton(app.LeftGrid, 'push', 'Text', '6. 故障诊断');
            app.RunDiagnosisButton.ButtonPushedFcn = createCallbackFcn(app, @runDiagnosisButtonPushed, true);
            app.SaveWorkspaceButton = uibutton(app.LeftGrid, 'push', 'Text', '保存当前结果');
            app.SaveWorkspaceButton.ButtonPushedFcn = createCallbackFcn(app, @saveWorkspaceButtonPushed, true);

            statusGrid = uigridlayout(app.LeftGrid, [1 2]);
            statusGrid.ColumnWidth = {24, '1x'};
            statusGrid.Padding = [0 0 0 0];
            app.StatusLamp = uilamp(statusGrid);
            app.StatusLamp.Layout.Row = 1; app.StatusLamp.Layout.Column = 1;
            app.StatusLabel = uilabel(statusGrid, 'Text', '就绪');
            app.StatusLabel.Layout.Row = 1; app.StatusLabel.Layout.Column = 2;

            uilabel(app.LeftGrid, 'Text', '运行日志');
            app.LogTextArea = uitextarea(app.LeftGrid);
            app.LogTextArea.Editable = 'off';

            app.RightTabGroup = uitabgroup(app.MainGrid);
            app.RightTabGroup.Layout.Row = 1;
            app.RightTabGroup.Layout.Column = 2;

            app.DataTab = uitab(app.RightTabGroup, 'Title', '数据导入');
            app.VisualTab = uitab(app.RightTabGroup, 'Title', '数据可视化');
            app.FeatureTab = uitab(app.RightTabGroup, 'Title', '特征提取');
            app.AnalysisTab = uitab(app.RightTabGroup, 'Title', '特征分析');
            app.DiagnosisTab = uitab(app.RightTabGroup, 'Title', '诊断');

            app.DataGrid = uigridlayout(app.DataTab, [3 1]);
            app.DataGrid.RowHeight = {160, '1x', '1x'};
            app.SummaryTable = uitable(app.DataGrid);
            app.GuidedPreviewTable = uitable(app.DataGrid);
            app.FiberPreviewTable = uitable(app.DataGrid);

            visualOuter = uigridlayout(app.VisualTab, [2 1]);
            visualOuter.RowHeight = {90, '1x'};
            visualOuter.Padding = [8 8 8 8];
            ctrlGrid = uigridlayout(visualOuter, [2 6]);
            ctrlGrid.RowHeight = {22, 28};
            ctrlGrid.ColumnWidth = {90, 150, 90, 150, 120, 120};
            uilabel(ctrlGrid, 'Text', '信号字段');
            uilabel(ctrlGrid, 'Text', '时频工况');
            uilabel(ctrlGrid, 'Text', '光纤工况');
            uilabel(ctrlGrid, 'Text', '时频方法');
            uilabel(ctrlGrid, 'Text', '趋势特征');
            uilabel(ctrlGrid, 'Text', '');
            app.SignalFieldDropDown = uidropdown(ctrlGrid, 'Items', {'s1_50k'});
            app.SignalFieldDropDown.ValueChangedFcn = createCallbackFcn(app, @onSignalSelectionChanged, true);
            app.ConditionDropDown = uidropdown(ctrlGrid, 'Items', {'N0'});
            app.ConditionDropDown.ValueChangedFcn = createCallbackFcn(app, @onSignalSelectionChanged, true);
            app.FiberConditionListBox = uilistbox(ctrlGrid, 'Multiselect', 'on', 'Items', {'N0'});
            app.FiberConditionListBox.ValueChangedFcn = createCallbackFcn(app, @onSignalSelectionChanged, true);
            app.TimeFreqMethodDropDown = uidropdown(ctrlGrid, 'Items', {'spectrogram','cwt'}, 'Value', 'spectrogram');
            app.TimeFreqMethodDropDown.ValueChangedFcn = createCallbackFcn(app, @onSignalSelectionChanged, true);
            app.FeatureNameDropDown = uidropdown(ctrlGrid, 'Items', {'GW_DamageIndex'});
            app.FeatureNameDropDown.ValueChangedFcn = createCallbackFcn(app, @onSignalSelectionChanged, true);
            app.PlotAllButton = uibutton(ctrlGrid, 'push', 'Text', '更新全部图');
            app.PlotAllButton.ButtonPushedFcn = createCallbackFcn(app, @plotAllButtonPushed, true);

            app.VisualGrid = uigridlayout(visualOuter, [3 2]);
            app.VisualGrid.RowHeight = {'1x','1x','1x'};
            app.VisualGrid.ColumnWidth = {'1x','1x'};
            app.GWOverlayAxes = uiaxes(app.VisualGrid);
            app.ConditionMapAxes = uiaxes(app.VisualGrid);
            app.TimeFreqAxes = uiaxes(app.VisualGrid);
            app.FiberOverlayAxes = uiaxes(app.VisualGrid);
            app.DamageTrendAxes = uiaxes(app.VisualGrid);
            app.FeatureTrendAxes = uiaxes(app.VisualGrid);

            app.FeatureGrid = uigridlayout(app.FeatureTab, [2 1]);
            app.FeatureGrid.RowHeight = {60, '1x'};
            topFeatureGrid = uigridlayout(app.FeatureGrid, [1 4]);
            topFeatureGrid.ColumnWidth = {180, 120, 120, '1x'};
            app.FeatureTypeDropDown = uidropdown(topFeatureGrid, 'Items', {'导波逐信号特征','光纤逐工况特征','导波工况聚合特征','融合工况特征'}, 'Value', '融合工况特征');
            app.FeatureTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @onFeatureTypeChanged, true);
            app.PreviewFeatureButton = uibutton(topFeatureGrid, 'push', 'Text', '刷新预览');
            app.PreviewFeatureButton.ButtonPushedFcn = createCallbackFcn(app, @previewFeatureButtonPushed, true);
            app.ExportFeatureButton = uibutton(topFeatureGrid, 'push', 'Text', '导出融合 CSV');
            app.ExportFeatureButton.ButtonPushedFcn = createCallbackFcn(app, @exportFeatureButtonPushed, true);
            uilabel(topFeatureGrid, 'Text', '');
            featureInnerGrid = uigridlayout(app.FeatureGrid, [1 2]);
            featureInnerGrid.ColumnWidth = {'2x', '1x'};
            app.FeaturePreviewTable = uitable(featureInnerGrid);
            app.FeatureInfoTextArea = uitextarea(featureInnerGrid);
            app.FeatureInfoTextArea.Editable = 'off';

            app.AnalysisGrid = uigridlayout(app.AnalysisTab, [2 3]);
            app.AnalysisGrid.RowHeight = {38, '1x'};
            app.PlotPCAButton = uibutton(app.AnalysisGrid, 'push', 'Text', 'PCA');
            app.PlotPCAButton.ButtonPushedFcn = @(src,event) app.plotPCA();
            app.PlotTSNEButton = uibutton(app.AnalysisGrid, 'push', 'Text', 't-SNE');
            app.PlotTSNEButton.ButtonPushedFcn = @(src,event) app.plotTSNE();
            app.PlotCorrButton = uibutton(app.AnalysisGrid, 'push', 'Text', '相关性热图');
            app.PlotCorrButton.ButtonPushedFcn = @(src,event) app.plotCorrelationHeatmap();
            app.PCAAxes = uiaxes(app.AnalysisGrid);
            app.TSNEAxes = uiaxes(app.AnalysisGrid);
            app.CorrAxes = uiaxes(app.AnalysisGrid);
            app.PCAAxes.Layout.Row = 2; app.PCAAxes.Layout.Column = 1;
            app.TSNEAxes.Layout.Row = 2; app.TSNEAxes.Layout.Column = 2;
            app.CorrAxes.Layout.Row = 2; app.CorrAxes.Layout.Column = 3;

            app.DiagnosisGrid = uigridlayout(app.DiagnosisTab, [2 2]);
            app.DiagnosisGrid.RowHeight = {'1x', 140};
            app.DiagnosisGrid.ColumnWidth = {'1x','1x'};
            app.AnomalyAxes = uiaxes(app.DiagnosisGrid);
            app.ConfusionAxes = uiaxes(app.DiagnosisGrid);
            app.ImportanceAxes = uiaxes(app.DiagnosisGrid);
            app.DiagnosisMetricsTextArea = uitextarea(app.DiagnosisGrid);
            app.DiagnosisMetricsTextArea.Editable = 'off';
            app.AnomalyAxes.Layout.Row = 1; app.AnomalyAxes.Layout.Column = 1;
            app.ConfusionAxes.Layout.Row = 1; app.ConfusionAxes.Layout.Column = 2;
            app.ImportanceAxes.Layout.Row = 2; app.ImportanceAxes.Layout.Column = 1;
            app.DiagnosisMetricsTextArea.Layout.Row = 2; app.DiagnosisMetricsTextArea.Layout.Column = 2;

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)
        function app = FaultDiagnosisPlatformApp_exported
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            try
                delete(app.UIFigure)
            catch
            end
        end
    end
end

function y = fillNanLinear(y)
y = double(y(:));
idx = find(isfinite(y));
if isempty(idx)
    y(:) = 0;
    return;
elseif numel(idx) == 1
    y(~isfinite(y)) = y(idx);
    return;
end
bad = ~isfinite(y);
y(bad) = interp1(idx, y(idx), find(bad), 'linear', 'extrap');
end

function m = meanFinite(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = mean(x);
end
end

function m = maxFinite(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
else
    m = max(x);
end
end

function c = corrFinite(x, y)
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);
if numel(x) < 2 || numel(unique(x)) < 2 || numel(unique(y)) < 2
    c = NaN;
    return;
end
C = corrcoef(x, y);
if numel(C) >= 2
    c = C(1,2);
else
    c = NaN;
end
end

function [x2, y2] = uniqueXY(x, y)
x = double(x(:));
y = double(y(:));
mask = isfinite(x);
x = x(mask);
y = y(mask);
if isempty(x)
    x2 = [];
    y2 = [];
    return;
end
[x, order] = sort(x);
y = y(order);
[xu, ~, ic] = unique(x, 'stable');
if numel(xu) == numel(x)
    x2 = x;
    y2 = y;
    return;
end
y2 = accumarray(ic, y, [], @meanNoNan);
x2 = xu;
end

function m = meanNoNan(v)
v = v(isfinite(v));
if isempty(v)
    m = NaN;
else
    m = mean(v);
end
end

function s = emptyFiberStruct(s)
keys = {'Mean','Std','Min','Max','Range','MaxAbs','RMSEnergy','GradEnergy','GradMaxAbs','PeakLocation','BaselineCorr','BaselineRMSE','BaselineMAE','BaselineShiftMean'};
for i = 1:numel(keys)
    s.(keys{i}) = NaN;
end
end

function M = readNumericByTextscan(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('无法打开 txt 文件：%s', filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
C = textscan(fid, '%f%f%f%f%f%f%f%f', 'Delimiter', {'\t', ' ', ',', ';'}, ...
    'MultipleDelimsAsOne', true, 'HeaderLines', 0, 'CollectOutput', true);
M = C{1};
end

function labels = recursiveFindPathLabels(x)
labels = strings(0,1);
if isstruct(x)
    fns = fieldnames(x);
    for i = 1:numel(fns)
        labels = [labels; recursiveFindPathLabels(x.(fns{i}))]; %#ok<AGROW>
    end
elseif iscell(x)
    for i = 1:numel(x)
        labels = [labels; recursiveFindPathLabels(x{i})]; %#ok<AGROW>
    end
elseif isstring(x) || ischar(x)
    txt = string(x);
    tok = regexp(txt, '(\d-\d)', 'match');
    if ~isempty(tok)
        labels = [labels; string(tok(:))]; %#ok<AGROW>
    end
end
end

function y = movingAverage(x, w)
if nargin < 2
    w = 5;
end
w = max(1, floor(w));
k = ones(w,1) / w;
y = conv(double(x(:)), k, 'same');
end

function w = makeValidWindow(desired, n)
w = min(desired, n);
if mod(w,2) == 0
    w = w - 1;
end
w = max(w, 3);
end

function n = heightSafe(T)
if isempty(T)
    n = 0;
else
    n = height(T);
end
end

function n = uniqueCount(T, varName)
if isempty(T) || height(T) == 0 || ~ismember(varName, T.Properties.VariableNames)
    n = 0;
else
    n = numel(unique(T.(varName)));
end
end

function n = signalFieldCount(T)
if isempty(T) || height(T) == 0 || ~ismember('SignalField', T.Properties.VariableNames)
    n = 0;
else
    n = numel(unique(T.SignalField));
end
end

function n = sampleCountMean(T)
if isempty(T) || height(T) == 0 || ~ismember('ProcProfile', T.Properties.VariableNames)
    n = 0;
else
    c = cellfun(@numel, T.ProcProfile);
    n = round(mean(c));
end
end

function n = numNumericCols(T)
if isempty(T) || height(T) == 0
    n = 0;
    return;
end
vars = T.Properties.VariableNames;
n = 0;
for i = 1:numel(vars)
    if isnumeric(T.(vars{i}))
        n = n + 1;
    end
end
end
