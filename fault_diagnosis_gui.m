function fault_diagnosis_gui()
%FAULT_DIAGNOSIS_GUI 故障诊断平台主界面
% 集成：数据导入、数据可视化（时频图）、特征提取、特征分析、诊断
%
% 使用方法：
% 在 MATLAB 命令窗口运行：fault_diagnosis_gui()
% 确保 config_project.m 和 helpers/ 文件夹在路径中

%% ======================= 全局状态 =======================
state = struct();
state.cfg = [];
state.guidedDS = [];    % 导波 dataset
state.fiberDS = [];     % 光纤 dataset
state.guidedFeat = [];
state.fiberFeat = [];
state.guidedAgg = [];
state.fusedFeat = [];
state.diagResult = [];

%% ======================= 主窗口 =======================
scrSz = get(0,'ScreenSize');
figW = min(1400, scrSz(3)-60);
figH = min(860, scrSz(4)-80);
figX = (scrSz(3)-figW)/2;
figY = (scrSz(4)-figH)/2;

hFig = figure('Name','故障诊断平台 v2.0','NumberTitle','off', ...
    'MenuBar','none','ToolBar','none','Resize','on', ...
    'Position',[figX figY figW figH],'Color',[0.13 0.14 0.18], ...
    'CloseRequestFcn',@onClose);

%% ======================= 颜色主题 =======================
C.bg      = [0.13 0.14 0.18];  % 深底色
C.panel   = [0.17 0.19 0.24];  % 面板色
C.card    = [0.20 0.22 0.28];  % 卡片色
C.accent  = [0.25 0.65 0.95];  % 主蓝
C.green   = [0.27 0.80 0.55];  % 成功绿
C.orange  = [0.97 0.60 0.25];  % 警告橙
C.red     = [0.92 0.35 0.35];  % 错误红
C.textPri = [0.93 0.94 0.96];  % 主文字
C.textSec = [0.55 0.60 0.68];  % 次文字
C.border  = [0.25 0.28 0.35];  % 边框
C.axBg    = [0.11 0.12 0.16];  % 坐标轴底色

%% ======================= 左侧导航栏 =======================
NAV_W = 200;
hNav = uipanel('Parent',hFig,'BackgroundColor',C.panel, ...
    'BorderType','none','Units','pixels', ...
    'Position',[0 0 NAV_W figH]);

% Logo 区
uicontrol('Parent',hNav,'Style','text', ...
    'String','⚡ FaultDiag','Units','pixels', ...
    'Position',[10 figH-70 NAV_W-20 50], ...
    'FontName','Consolas','FontSize',16,'FontWeight','bold', ...
    'ForegroundColor',C.accent,'BackgroundColor',C.panel, ...
    'HorizontalAlignment','center');

uicontrol('Parent',hNav,'Style','text', ...
    'String','导波·光纤·融合诊断','Units','pixels', ...
    'Position',[10 figH-92 NAV_W-20 22], ...
    'FontName','SimHei','FontSize',9, ...
    'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
    'HorizontalAlignment','center');

% 分隔线
uicontrol('Parent',hNav,'Style','text','String','', ...
    'Units','pixels','Position',[15 figH-100 NAV_W-30 1], ...
    'BackgroundColor',C.border);

% 导航按钮定义
navItems = { ...
    '📂 数据导入', 'import'; ...
    '📊 数据可视化', 'visual'; ...
    '🔬 特征提取', 'feat'; ...
    '📈 特征分析', 'analysis';...
    '🤖 故障诊断', 'diag'};

hNavBtns = zeros(1,size(navItems,1));
NAV_BTN_H = 48;
startY = figH - 160;

for i = 1:size(navItems,1)
    hNavBtns(i) = uicontrol('Parent',hNav,'Style','pushbutton', ...
        'String',navItems{i,1},'Units','pixels', ...
        'Position',[10 startY-(i-1)*(NAV_BTN_H+4) NAV_W-20 NAV_BTN_H], ...
        'FontName','SimHei','FontSize',11,'FontWeight','bold', ...
        'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
        'HorizontalAlignment','left', ...
        'Callback',{@onNavClick, navItems{i,2}});
    % 悬停效果通过 ButtonDownFcn 模拟
end

% 底部状态
hStatus = uicontrol('Parent',hNav,'Style','text', ...
    'String','就绪','Units','pixels', ...
    'Position',[10 8 NAV_W-20 28], ...
    'FontName','SimHei','FontSize',9, ...
    'ForegroundColor',C.green,'BackgroundColor',C.panel, ...
    'HorizontalAlignment','center');

%% ======================= 内容区 =======================
CONT_X = NAV_W + 6;
CONT_W = figW - CONT_X - 6;
CONT_H = figH - 6;

% 五个页面 Panel
hPages = struct();
hPages.import   = makePage(hFig, CONT_X, 3, CONT_W, CONT_H, C);
hPages.visual   = makePage(hFig, CONT_X, 3, CONT_W, CONT_H, C);
hPages.feat     = makePage(hFig, CONT_X, 3, CONT_W, CONT_H, C);
hPages.analysis = makePage(hFig, CONT_X, 3, CONT_W, CONT_H, C);
hPages.diag     = makePage(hFig, CONT_X, 3, CONT_W, CONT_H, C);

%% ---- 构建各页面内容 ----
buildImportPage(hPages.import, C, CONT_W, CONT_H);
buildVisualPage(hPages.visual, C, CONT_W, CONT_H);
buildFeatPage(hPages.feat, C, CONT_W, CONT_H);
buildAnalysisPage(hPages.analysis, C, CONT_W, CONT_H);
buildDiagPage(hPages.diag, C, CONT_W, CONT_H);

%% 默认显示 import 页面
showPage('import');

%% ======================= 内嵌函数 =======================

    function p = makePage(parent, x, y, w, h, C)
        p = uipanel('Parent',parent,'BackgroundColor',C.bg, ...
            'BorderType','none','Units','pixels', ...
            'Position',[x y w h],'Visible','off');
    end

    function showPage(name)
        fields = fieldnames(hPages);
        for fi = 1:numel(fields)
            set(hPages.(fields{fi}), 'Visible', 'off');
        end
        set(hPages.(name), 'Visible', 'on');
        
        % 高亮当前导航按钮
        for bi = 1:size(navItems,1)
            if strcmp(navItems{bi,2}, name)
                set(hNavBtns(bi),'BackgroundColor', C.accent, ...
                    'ForegroundColor',[0.05 0.05 0.08]);
            else
                set(hNavBtns(bi),'BackgroundColor', C.card, ...
                    'ForegroundColor', C.textPri);
            end
        end
    end

    function onNavClick(~, ~, name)
        showPage(name);
    end

    function onClose(~, ~)
        delete(hFig);
    end

%% ============================================================
%% 页面1：数据导入
%% ============================================================
    function buildImportPage(parent, C, W, H)
        % 标题
        makeTitle(parent, '📂 数据导入', C, W, H);
        
        % 配置路径卡片
        makeCardTitle(parent, '项目配置', C, 20, H-100, W-40, 24);
        hCfgTxt = uicontrol('Parent',parent,'Style','edit', ...
            'String','(点击"自动加载"或手动输入 config_project.m 所在目录)', ...
            'Units','pixels','Position',[20 H-140 W-160 32], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'HorizontalAlignment','left');
        makeBtn(parent,'自动加载', C.accent, [W-132 H-140 110 32], ...
            @(~,~)doAutoLoad(hCfgTxt), C);
        
        % 导波目录
        makeCardTitle(parent, '导波数据目录', C, 20, H-200, W-40, 24);
        hGWDir = uicontrol('Parent',parent,'Style','edit', ...
            'String','','Units','pixels','Position',[20 H-240 W-160 32], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'HorizontalAlignment','left');
        makeBtn(parent,'浏览...', C.card, [W-132 H-240 110 32], ...
            @(~,~)browseDir(hGWDir), C);
        
        % 光纤目录
        makeCardTitle(parent, '光纤数据目录', C, 20, H-300, W-40, 24);
        hFBDir = uicontrol('Parent',parent,'Style','edit', ...
            'String','','Units','pixels','Position',[20 H-340 W-160 32], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'HorizontalAlignment','left');
        makeBtn(parent,'浏览...', C.card, [W-132 H-340 110 32], ...
            @(~,~)browseDir(hFBDir), C);
        
        % 操作按钮行
        makeBtn(parent,'▶ 构建导波数据集', C.accent, [20 H-400 200 40], ...
            @(~,~)doBuildGuided(hGWDir), C);
        makeBtn(parent,'▶ 构建光纤数据集', C.green, [240 H-400 200 40], ...
            @(~,~)doBuildFiber(hFBDir), C);
        makeBtn(parent,'▶ 加载已有输出', C.orange, [460 H-400 180 40], ...
            @(~,~)doLoadExisting(), C);
        
        % 状态卡片
        makeCardTitle(parent,'数据状态', C, 20, H-460, W-40, 24);
        hInfoTxt = uicontrol('Parent',parent,'Style','listbox', ...
            'String',{'[等待数据加载...]'}, ...
            'Units','pixels','Position',[20 H-640 W-40 170], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',10);
        
        function doAutoLoad(hEdit)
            try
                cfg = config_project();
                state.cfg = cfg;
                addpath(genpath(cfg.platformRoot));
                set(hEdit,'String', cfg.platformRoot);
                set(hGWDir,'String', cfg.guidedWaveDir);
                set(hFBDir,'String', cfg.fiberDir);
                setStatus('配置已加载', C.green);
                appendLog(hInfoTxt, {'✅ config_project 加载成功', ...
                    ['   platformRoot: ' cfg.platformRoot], ...
                    ['   导波目录: ' cfg.guidedWaveDir], ...
                    ['   光纤目录: ' cfg.fiberDir]});
            catch ex
                appendLog(hInfoTxt, {['❌ 加载失败: ' ex.message]});
                setStatus('配置加载失败', C.red);
            end
        end
        
        function browseDir(hEdit)
            d = uigetdir(get(hEdit,'String'),'选择目录');
            if ischar(d) && ~isequal(d,0)
                set(hEdit,'String',d);
            end
        end
        
        function doBuildGuided(hEdit)
            if isempty(state.cfg), tryLoadCfg(); end
            if isempty(state.cfg), return; end
            
            gwDir = strtrim(get(hEdit,'String'));
            if ~isempty(gwDir), state.cfg.guidedWaveDir = gwDir; end
            
            setStatus('正在构建导波数据集...', C.orange);
            appendLog(hInfoTxt,{'🔄 开始构建导波数据集...'});
            try
                state.guidedDS = buildGuidedDataset(state.cfg);
                appendLog(hInfoTxt,{ ...
                    '✅ 导波数据集构建完成', ...
                    sprintf('   记录数: %d', height(state.guidedDS)), ...
                    sprintf('   工况数: %d', numel(unique(state.guidedDS.ConditionName)))});
                setStatus('导波数据集就绪', C.green);
            catch ex
                appendLog(hInfoTxt,{['❌ 导波构建失败: ' ex.message]});
                setStatus('构建失败', C.red);
            end
        end
        
        function doBuildFiber(hEdit)
            if isempty(state.cfg), tryLoadCfg(); end
            if isempty(state.cfg), return; end
            
            fbDir = strtrim(get(hEdit,'String'));
            if ~isempty(fbDir), state.cfg.fiberDir = fbDir; end
            
            setStatus('正在构建光纤数据集...', C.orange);
            appendLog(hInfoTxt,{'🔄 开始构建光纤数据集...'});
            try
                state.fiberDS = buildFiberDataset(state.cfg);
                appendLog(hInfoTxt,{ ...
                    '✅ 光纤数据集构建完成', ...
                    sprintf('   工况数: %d', height(state.fiberDS))});
                setStatus('光纤数据集就绪', C.green);
            catch ex
                appendLog(hInfoTxt,{['❌ 光纤构建失败: ' ex.message]});
                setStatus('构建失败', C.red);
            end
        end
        
        function doLoadExisting()
            if isempty(state.cfg), tryLoadCfg(); end
            if isempty(state.cfg), return; end
            msgs = {};
            if isfile(state.cfg.guidedDatasetFile)
                S = load(state.cfg.guidedDatasetFile,'dataset');
                state.guidedDS = S.dataset;
                msgs{end+1} = sprintf('✅ 导波数据集: %d 条记录', height(state.guidedDS));
            else
                msgs{end+1} = '⚠ 未找到导波数据集文件';
            end
            
            if isfile(state.cfg.fiberDatasetFile)
                S = load(state.cfg.fiberDatasetFile,'dataset');
                state.fiberDS = S.dataset;
                msgs{end+1} = sprintf('✅ 光纤数据集: %d 条记录', height(state.fiberDS));
            else
                msgs{end+1} = '⚠ 未找到光纤数据集文件';
            end
            
            if isfile(state.cfg.featureFile)
                S = load(state.cfg.featureFile);
                if isfield(S,'guidedFeat'), state.guidedFeat = S.guidedFeat; end
                if isfield(S,'fiberFeat'),  state.fiberFeat = S.fiberFeat; end
                if isfield(S,'guidedAgg'),  state.guidedAgg = S.guidedAgg; end
                if isfield(S,'fusedFeat'),  state.fusedFeat = S.fusedFeat; end
                msgs{end+1} = sprintf('✅ 特征文件: 融合特征 %d 行', height(state.fusedFeat));
            else
                msgs{end+1} = '⚠ 未找到特征文件';
            end
            
            appendLog(hInfoTxt, msgs);
            setStatus('数据加载完成', C.green);
        end
        
        function tryLoadCfg()
            try
                state.cfg = config_project();
                addpath(genpath(state.cfg.platformRoot));
            catch
                errordlg('无法加载 config_project，请确保路径正确。','配置错误');
            end
        end
    end

%% ============================================================
%% 页面2：数据可视化
%% ============================================================
    function buildVisualPage(parent, C, W, H)
        makeTitle(parent, '📊 数据可视化', C, W, H);
        
        % 左控制栏
        CTRL_W = 240;
        hCtrlPanel = uipanel('Parent',parent,'BackgroundColor',C.panel, ...
            'BorderType','none','Units','pixels', ...
            'Position',[10 10 CTRL_W H-80]);
        
        % 可视化类型
        uicontrol('Parent',hCtrlPanel,'Style','text','String','可视化类型', ...
            'Units','pixels','Position',[10 H-130 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        vizTypes = {'导波波形叠加','单信号时域','单信号频谱', ...
            '短时傅里叶（STFT）','小波时频图（CWT）', ...
            '光纤 Profile 叠加','损伤指标趋势'};
        hVizType = uicontrol('Parent',hCtrlPanel,'Style','listbox', ...
            'String',vizTypes,'Units','pixels', ...
            'Position',[10 H-290 CTRL_W-20 150], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card,'Value',1);
        
        % 工况选择
        uicontrol('Parent',hCtrlPanel,'Style','text','String','选择工况', ...
            'Units','pixels','Position',[10 H-318 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hCondList = uicontrol('Parent',hCtrlPanel,'Style','listbox', ...
            'String',{'(加载数据后刷新)'},'Units','pixels', ...
            'Position',[10 H-450 CTRL_W-20 125], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',8,'Min',1);
            
        % 信号字段
        uicontrol('Parent',hCtrlPanel,'Style','text','String','信号字段', ...
            'Units','pixels','Position',[10 H-478 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hSigField = uicontrol('Parent',hCtrlPanel,'Style','popupmenu', ...
            'String',{'(自动)'},'Units','pixels', ...
            'Position',[10 H-512 CTRL_W-20 28], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card);
            
        % 路径标签
        uicontrol('Parent',hCtrlPanel,'Style','text','String','路径标签', ...
            'Units','pixels','Position',[10 H-540 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hPathLabel = uicontrol('Parent',hCtrlPanel,'Style','popupmenu', ...
            'String',{'(全部)'},'Units','pixels', ...
            'Position',[10 H-572 CTRL_W-20 28], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card);
            
        % 刷新 & 绘图
        makeBtn(hCtrlPanel,'🔄 刷新列表', C.card, [10 H-630 CTRL_W-20 36], ...
            @(~,~)refreshCondList(), C);
        makeBtn(hCtrlPanel,'▶ 绘图', C.accent, [10 H-676 CTRL_W-20 40], ...
            @(~,~)doPlot(), C);
        makeBtn(hCtrlPanel,'💾 保存图像', C.green, [10 H-726 CTRL_W-20 36], ...
            @(~,~)doSaveFig(), C);
            
        % 右侧坐标轴区域
        AX_X = CTRL_W + 20;
        AX_W = W - AX_X - 16;
        AX_H = H - 90;
        
        hAx = axes('Parent',parent,'Units','pixels', ...
            'Position',[AX_X 10 AX_W AX_H], ...
            'Color',C.axBg,'XColor',C.textSec,'YColor',C.textSec, ...
            'GridColor',C.border,'GridAlpha',0.4,'Box','on');
        text(hAx, 0.5, 0.5, '选择可视化类型并点击 ▶ 绘图', ...
            'HorizontalAlignment','center','Color',C.textSec, ...
            'FontSize',14,'FontName','SimHei', ...
            'Units','normalized');
            
        function refreshCondList()
            if ~isempty(state.guidedDS)
                conds = unique(state.guidedDS.ConditionName,'stable');
                set(hCondList,'String',cellstr(conds));
                
                % 信号字段
                fields = unique(state.guidedDS.SignalField,'stable');
                set(hSigField,'String',['(全部)'; cellstr(fields)]);
                
                % 路径
                paths = unique(state.guidedDS.PathLabel,'stable');
                set(hPathLabel,'String',['(全部)'; cellstr(paths)]);
                
                setStatus('列表已刷新',C.green);
            else
                setStatus('请先加载数据',C.orange);
            end
        end
        
        function doPlot()
            vIdx = get(hVizType,'Value');
            if isempty(state.guidedDS) && vIdx <= 5
                setStatus('请先导入导波数据',C.orange); return;
            end
            if isempty(state.fiberDS) && vIdx == 6
                setStatus('请先导入光纤数据',C.orange); return;
            end
            
            cla(hAx,'reset');
            set(hAx,'Color',C.axBg,'XColor',C.textSec,'YColor',C.textSec, ...
                'GridColor',C.border,'GridAlpha',0.4,'Box','on');
            axes(hAx);
            
            condIdxs = get(hCondList,'Value');
            condNames = get(hCondList,'String');
            selConds = string(condNames(condIdxs));
            
            sfIdx = get(hSigField,'Value');
            sfStr = get(hSigField,'String');
            sfSel = sfStr{sfIdx};
            
            plIdx = get(hPathLabel,'Value');
            plStr = get(hPathLabel,'String');
            plSel = plStr{plIdx};
            
            try
                switch vIdx
                    case 1, plotGWOverlay(hAx, selConds, sfSel, plSel, C);
                    case 2, plotGWSingle(hAx, selConds, sfSel, plSel, C, 'time');
                    case 3, plotGWSingle(hAx, selConds, sfSel, plSel, C, 'freq');
                    case 4, plotSTFT(hAx, selConds, sfSel, C);
                    case 5, plotCWT(hAx, selConds, sfSel, C);
                    case 6, plotFiberOverlay(hAx, selConds, C);
                    case 7, plotDamageTrend(hAx, C);
                end
                setStatus('绘图完成',C.green);
            catch ex
                text(hAx,0.5,0.5,['绘图错误: ' ex.message], ...
                    'HorizontalAlignment','center','Color',C.red, ...
                    'FontSize',11,'FontName','SimHei','Units','normalized');
                setStatus(['绘图失败: ' ex.message], C.red);
            end
        end
        
        function doSaveFig()
            if isempty(state.cfg), tryLoadCfgV(); end
            [fname, fpath] = uiputfile({'*.png','PNG图像';'*.pdf','PDF文档'}, ...
                '保存图像', fullfile(state.cfg.figureRoot, 'visualization.png'));
            if ischar(fname) && ~isequal(fname,0)
                hF2 = figure('Color','w');
                copyobj(hAx, hF2);
                saveas(hF2, fullfile(fpath,fname));
                close(hF2);
                setStatus(['图像已保存: ' fname], C.green);
            end
        end
        
        function tryLoadCfgV()
            try, state.cfg = config_project(); catch, end
        end
    end

%% ============================================================
%% 页面3：特征提取
%% ============================================================
    function buildFeatPage(parent, C, W, H)
        makeTitle(parent, '🔬 特征提取', C, W, H);
        
        % 说明
        uicontrol('Parent',parent,'Style','text', ...
            'String','从导波数据集和光纤数据集中提取时域、频域、包络等特征，并生成融合特征表。', ...
            'Units','pixels','Position',[20 H-110 W-40 30], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.bg, ...
            'HorizontalAlignment','left');
            
        % 特征类型选项
        makeCardTitle(parent,'导波特征选项', C, 20, H-155, W/2-30, 24);
        gwFeats = {'时域：峰值、RMS、能量、峰峰值','时域：偏度、峰度、波峰系数', ...
                   '频域：主频、谱中心、带宽偏差','包络：包络峰值、到达时刻', ...
                   '基线对比：相关性、RMSE、MAE、损伤指数'};
        hGWOpts = uicontrol('Parent',parent,'Style','listbox', ...
            'String',gwFeats,'Units','pixels', ...
            'Position',[20 H-330 W/2-30 165], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',5,'Value',1:5);
            
        makeCardTitle(parent,'光纤特征选项', C, W/2+10, H-155, W/2-30, 24);
        fbFeats = {'统计：均值、标准差、极值、范围','能量：梯度能量、梯度峰值', ...
                   '形状：峰值位置','基线对比：相关性、位移量'};
        hFBOpts = uicontrol('Parent',parent,'Style','listbox', ...
            'String',fbFeats,'Units','pixels', ...
            'Position',[W/2+10 H-330 W/2-30 165], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',4,'Value',1:4);
            
        % 操作按钮
        makeBtn(parent,'▶ 提取特征（全量）', C.accent, [20 H-388 220 44], ...
            @(~,~)doExtract(false), C);
        makeBtn(parent,'▶ 快速预览（首个工况）', C.card, [260 H-388 220 44], ...
            @(~,~)doExtract(true), C);
        makeBtn(parent,'💾 导出 CSV', C.green, [500 H-388 160 44], ...
            @(~,~)doExportCsv(), C);
            
        % 进度与日志
        makeCardTitle(parent,'提取日志', C, 20, H-430, W-40, 24);
        hLog = uicontrol('Parent',parent,'Style','listbox', ...
            'String',{'[等待提取...]'},'Units','pixels', ...
            'Position',[20 H-620 W-40 180], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',20);
            
        % 特征预览表
        makeCardTitle(parent,'融合特征预览（前5列/5行）', C, 20, H-670, W-40, 24);
        hPreview = uicontrol('Parent',parent,'Style','listbox', ...
            'String',{'(提取后显示)'},'Units','pixels', ...
            'Position',[20 H-820 W-40 140], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',10);
            
        function doExtract(previewOnly)
            if isempty(state.guidedDS) || isempty(state.fiberDS)
                appendLog(hLog,{'❌ 请先在数据导入页加载两类数据集'}); return;
            end
            if isempty(state.cfg), tryLoadCfgE(); end
            
            appendLog(hLog,{'🔄 开始提取特征...'});
            setStatus('正在提取特征...', C.orange);
            
            try
                cfg2 = state.cfg;
                gDS = state.guidedDS;
                fDS = state.fiberDS;
                
                if previewOnly
                    gDS = gDS(1:min(18,height(gDS)),:);
                    fDS = fDS(1:min(3,height(fDS)),:);
                    appendLog(hLog,{'[预览模式] 仅处理前几条记录'});
                end
                
                %-- 导波特征
                appendLog(hLog,{'   提取导波特征...'}); drawnow;
                rows = {};
                for ii = 1:height(gDS)
                    baseline = helpers.findBaselineGuidedWave(gDS, gDS.SignalField(ii));
                    feat = helpers.computeGuidedWaveFeatures( ...
                        gDS.ProcSignal{ii}, gDS.Envelope{ii}, ...
                        cfg2.fs, gDS.FrequencyKHz(ii), baseline);
                        
                    rows(ii,:) = { ...
                        gDS.ConditionName(ii), gDS.CycleNum(ii), ...
                        gDS.SignalField(ii), gDS.SignalId(ii), ...
                        gDS.FrequencyKHz(ii), gDS.PathLabel(ii), ...
                        feat.PeakAbs, feat.RMS, feat.Energy, feat.PeakToPeak, feat.Std, ...
                        feat.Skewness, feat.Kurtosis, feat.CrestFactor, feat.EnvelopePeak, ...
                        feat.ArrivalIndex, feat.DominantFreqKHz, feat.SpectralCentroidKHz, ...
                        feat.CenterFreqDeviationKHz, feat.BaselineCorr, feat.BaselineRMSE, ...
                        feat.BaselineMAE, feat.DamageIndex};
                end
                state.guidedFeat = cell2table(rows,'VariableNames',{ ...
                    'ConditionName','CycleNum','SignalField','SignalId','FrequencyKHz','PathLabel', ...
                    'GW_PeakAbs','GW_RMS','GW_Energy','GW_PeakToPeak','GW_Std', ...
                    'GW_Skewness','GW_Kurtosis','GW_CrestFactor','GW_EnvelopePeak', ...
                    'GW_ArrivalIndex','GW_DominantFreqKHz','GW_SpectralCentroidKHz', ...
                    'GW_CenterFreqDeviationKHz','GW_BaselineCorr','GW_BaselineRMSE', ...
                    'GW_BaselineMAE','GW_DamageIndex'});
                
                state.guidedFeat.StageLabel = helpers.assignStageLabel( ...
                    state.guidedFeat.CycleNum, cfg2.stageEdges, cfg2.stageNames);
                appendLog(hLog,{sprintf('   ✅ 导波特征：%d 行', height(state.guidedFeat))});
                
                %-- 聚合
                fVars = state.guidedFeat.Properties.VariableNames( ...
                    startsWith(state.guidedFeat.Properties.VariableNames,'GW_'));
                state.guidedAgg = groupsummary(state.guidedFeat, ...
                    {'ConditionName','CycleNum'},{'mean','max'},fVars);
                state.guidedAgg.StageLabel = helpers.assignStageLabel( ...
                    state.guidedAgg.CycleNum, cfg2.stageEdges, cfg2.stageNames);
                
                %-- 光纤特征
                appendLog(hLog,{'   提取光纤特征...'}); drawnow;
                rows2 = {};
                bsFiber = helpers.findBaselineFiber(fDS);
                for ii = 1:height(fDS)
                    feat2 = helpers.computeFiberFeatures( ...
                        fDS.XAxisProc{ii}, fDS.ProcProfile{ii}, ...
                        bsFiber.x, bsFiber.y);
                    rows2(ii,:) = { ...
                        fDS.ConditionName(ii), fDS.CycleNum(ii), ...
                        feat2.SampleCount, feat2.Mean, feat2.Std, feat2.Min, feat2.Max, feat2.Range, ...
                        feat2.MaxAbs, feat2.RMSEnergy, feat2.GradEnergy, feat2.GradMaxAbs, ...
                        feat2.PeakLocation, feat2.BaselineCorr, feat2.BaselineRMSE, ...
                        feat2.BaselineMAE, feat2.BaselineShiftMean};
                end
                state.fiberFeat = cell2table(rows2,'VariableNames',{ ...
                    'ConditionName','CycleNum', ...
                    'FB_SampleCount','FB_Mean','FB_Std','FB_Min','FB_Max','FB_Range', ...
                    'FB_MaxAbs','FB_RMSEnergy','FB_GradEnergy','FB_GradMaxAbs', ...
                    'FB_PeakLocation','FB_BaselineCorr','FB_BaselineRMSE', ...
                    'FB_BaselineMAE','FB_BaselineShiftMean'});
                state.fiberFeat.StageLabel = helpers.assignStageLabel( ...
                    state.fiberFeat.CycleNum, cfg2.stageEdges, cfg2.stageNames);
                appendLog(hLog,{sprintf('   ✅ 光纤特征：%d 行', height(state.fiberFeat))});
                
                %-- 融合
                state.fusedFeat = outerjoin(state.guidedAgg, state.fiberFeat, ...
                    'Keys',{'ConditionName','CycleNum'},'MergeKeys',true,'Type','left');
                state.fusedFeat.StageLabel = helpers.assignStageLabel( ...
                    state.fusedFeat.CycleNum, cfg2.stageEdges, cfg2.stageNames);
                
                appendLog(hLog,{sprintf('   ✅ 融合特征：%d 行 × %d 列', ...
                    height(state.fusedFeat), width(state.fusedFeat))});
                
                if ~previewOnly
                    save(cfg2.featureFile, 'state', '-v7.3');
                    appendLog(hLog,{['   💾 已保存：' cfg2.featureFile]});
                end
                
                % 预览
                showFeatPreview(hPreview);
                setStatus('特征提取完成', C.green);
                
            catch ex
                appendLog(hLog,{['❌ 提取失败: ' ex.message]});
                setStatus('特征提取失败', C.red);
            end
        end
        
        function doExportCsv()
            if isempty(state.fusedFeat)
                setStatus('请先提取特征', C.orange); return;
            end
            if isempty(state.cfg), tryLoadCfgE(); end
            
            [f,p] = uiputfile('*.csv','导出融合特征CSV', ...
                fullfile(state.cfg.outputRoot,'fused_features.csv'));
            if ischar(f) && ~isequal(f,0)
                try
                    writetable(state.fusedFeat, fullfile(p,f));
                    setStatus(['CSV已导出: ' f], C.green);
                    appendLog(hLog,{['💾 CSV导出: ' fullfile(p,f)]});
                catch ex
                    setStatus(['导出失败: ' ex.message], C.red);
                end
            end
        end
        
        function showFeatPreview(hCtrl)
            if isempty(state.fusedFeat), return; end
            T = state.fusedFeat;
            varNames = T.Properties.VariableNames;
            numVars = varNames(varfun(@isnumeric,T,'OutputFormat','uniform'));
            numVars = numVars(1:min(6,numel(numVars)));
            
            lines = {['变量:  ' strjoin(numVars,' | ')]};
            for ri = 1:min(5,height(T))
                vals = arrayfun(@(v) sprintf('%.4g',T.(v){ri}), numVars,'UniformOutput',false);
                lines{end+1} = ['行' num2str(ri) ':  ' strjoin(vals, ' | ')];
            end
            set(hCtrl,'String',lines);
        end
        
        function tryLoadCfgE()
            try, state.cfg = config_project(); catch, end
        end
    end

%% ============================================================
%% 页面4：特征分析
%% ============================================================
    function buildAnalysisPage(parent, C, W, H)
        makeTitle(parent, '📈 特征分析', C, W, H);
        
        CTRL_W = 230;
        hCtrlP = uipanel('Parent',parent,'BackgroundColor',C.panel, ...
            'BorderType','none','Units','pixels', ...
            'Position',[10 10 CTRL_W H-80]);
            
        uicontrol('Parent',hCtrlP,'Style','text','String','分析方法', ...
            'Units','pixels','Position',[10 H-130 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        anaMethods = {'PCA 降维散点图','t-SNE 散点图', ...
            '损伤指标趋势（全路径）','特征相关性热图', ...
            '特征箱线图（按健康阶段）','损伤指标 vs 工况数'};
        hAnaType = uicontrol('Parent',hCtrlP,'Style','listbox', ...
            'String',anaMethods,'Units','pixels', ...
            'Position',[10 H-310 CTRL_W-20 170], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card,'Value',1);
            
        uicontrol('Parent',hCtrlP,'Style','text','String','选择特征（箱线图）', ...
            'Units','pixels','Position',[10 H-338 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hFeatSel = uicontrol('Parent',hCtrlP,'Style','popupmenu', ...
            'String',{'(加载特征后刷新)'},'Units','pixels', ...
            'Position',[10 H-374 CTRL_W-20 28], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card);
            
        makeBtn(hCtrlP,'🔄 刷新特征列表', C.card, [10 H-424 CTRL_W-20 36], ...
            @(~,~)refreshFeatList(), C);
        makeBtn(hCtrlP,'▶ 运行分析', C.accent, [10 H-470 CTRL_W-20 40], ...
            @(~,~)doAnalysis(), C);
        makeBtn(hCtrlP,'💾 保存图像', C.green, [10 H-520 CTRL_W-20 36], ...
            @(~,~)doSaveAnaFig(), C);
            
        AX_X = CTRL_W + 20;
        AX_W = W - AX_X - 16;
        AX_H = H - 90;
        hAnaAx = axes('Parent',parent,'Units','pixels', ...
            'Position',[AX_X 10 AX_W AX_H], ...
            'Color',C.axBg,'XColor',C.textSec,'YColor',C.textSec, ...
            'GridColor',C.border,'GridAlpha',0.4,'Box','on');
        text(hAnaAx,0.5,0.5,'选择分析方法并点击 ▶ 运行分析', ...
            'HorizontalAlignment','center','Color',C.textSec, ...
            'FontSize',14,'FontName','SimHei','Units','normalized');
            
        function refreshFeatList()
            if isempty(state.fusedFeat)
                setStatus('请先提取特征',C.orange); return;
            end
            numVars = state.fusedFeat.Properties.VariableNames( ...
                varfun(@isnumeric,state.fusedFeat,'OutputFormat','uniform'));
            set(hFeatSel,'String',numVars,'Value',1);
            setStatus('特征列表已刷新',C.green);
        end
        
        function doAnalysis()
            if isempty(state.fusedFeat)
                setStatus('请先提取特征',C.orange); return;
            end
            cla(hAnaAx,'reset');
            set(hAnaAx,'Color',C.axBg,'XColor',C.textSec,'YColor',C.textSec, ...
                'GridColor',C.border,'GridAlpha',0.4,'Box','on');
            axes(hAnaAx);
            
            aIdx = get(hAnaType,'Value');
            T = state.fusedFeat;
            try
                switch aIdx
                    case 1, runPCA(hAnaAx, T, C);
                    case 2, runTSNE(hAnaAx, T, C);
                    case 3, runDamageTrendFull(hAnaAx, C);
                    case 4, runCorrHeatmap(hAnaAx, T, C);
                    case 5
                        featStr = get(hFeatSel,'String');
                        featIdx = get(hFeatSel,'Value');
                        if iscell(featStr), fName = featStr{featIdx};
                        else, fName = featStr; end
                        runBoxplot(hAnaAx, T, fName, C);
                    case 6, runDmgVsCycle(hAnaAx, T, C);
                end
                setStatus('分析完成', C.green);
            catch ex
                text(hAnaAx,0.5,0.5,['分析错误: ' ex.message], ...
                    'HorizontalAlignment','center','Color',C.red, ...
                    'FontSize',11,'FontName','SimHei','Units','normalized');
                setStatus(['分析失败: ' ex.message], C.red);
            end
        end
        
        function doSaveAnaFig()
            if isempty(state.cfg)
                try, state.cfg = config_project(); catch, end
            end
            outDir = '';
            if ~isempty(state.cfg), outDir = state.cfg.figureRoot; end
            [f,p] = uiputfile({'*.png';'*.pdf'},'保存图像', ...
                fullfile(outDir,'analysis.png'));
            if ischar(f) && ~isequal(f,0)
                hF2 = figure('Color','w');
                copyobj(hAnaAx, hF2);
                saveas(hF2, fullfile(p,f));
                close(hF2);
                setStatus(['图像已保存: ' f], C.green);
            end
        end
    end

%% ============================================================
%% 页面5：故障诊断
%% ============================================================
    function buildDiagPage(parent, C, W, H)
        makeTitle(parent, '🤖 故障诊断', C, W, H);
        
        CTRL_W = 240;
        hCtrlP = uipanel('Parent',parent,'BackgroundColor',C.panel, ...
            'BorderType','none','Units','pixels', ...
            'Position',[10 10 CTRL_W H-80]);
            
        % 模型选择
        uicontrol('Parent',hCtrlP,'Style','text','String','分类器', ...
            'Units','pixels','Position',[10 H-130 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hMdlType = uicontrol('Parent',hCtrlP,'Style','popupmenu', ...
            'String',{'随机森林（Bag）','AdaBoost','KNN','决策树（单棵）'}, ...
            'Units','pixels','Position',[10 H-166 CTRL_W-20 28], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card);
            
        % 交叉验证
        uicontrol('Parent',hCtrlP,'Style','text','String','交叉验证折数 K', ...
            'Units','pixels','Position',[10 H-200 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hKFold = uicontrol('Parent',hCtrlP,'Style','edit','String','5', ...
            'Units','pixels','Position',[10 H-232 CTRL_W-20 28], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'HorizontalAlignment','center');
            
        % 树数量
        uicontrol('Parent',hCtrlP,'Style','text','String','集成树数量', ...
            'Units','pixels','Position',[10 H-268 CTRL_W-20 22], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textSec,'BackgroundColor',C.panel, ...
            'HorizontalAlignment','left');
        hNTrees = uicontrol('Parent',hCtrlP,'Style','edit','String','100', ...
            'Units','pixels','Position',[10 H-298 CTRL_W-20 28], ...
            'FontName','SimHei','FontSize',10, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'HorizontalAlignment','center');
            
        makeBtn(hCtrlP,'▶ 开始训练与诊断', C.accent, [10 H-358 CTRL_W-20 50], ...
            @(~,~)doTrain(), C);
        makeBtn(hCtrlP,'📊 异常度评分图', C.card, [10 H-418 CTRL_W-20 36], ...
            @(~,~)showAnomalyPlot(), C);
        makeBtn(hCtrlP,'📊 混淆矩阵', C.card, [10 H-464 CTRL_W-20 36], ...
            @(~,~)showConfMat(), C);
        makeBtn(hCtrlP,'📊 特征重要性', C.card, [10 H-510 CTRL_W-20 36], ...
            @(~,~)showImportance(), C);
        makeBtn(hCtrlP,'💾 保存模型', C.green, [10 H-558 CTRL_W-20 36], ...
            @(~,~)doSaveModel(), C);
            
        % 结果区
        AX_X = CTRL_W + 20;
        AX_W = W - AX_X - 16;
        AX_H_TOP = round((H-90) * 0.55);
        AX_H_BOT = H - 90 - AX_H_TOP - 10;
        
        hDiagAx1 = axes('Parent',parent,'Units','pixels', ...
            'Position',[AX_X 10+AX_H_BOT+10 AX_W AX_H_TOP], ...
            'Color',C.axBg,'XColor',C.textSec,'YColor',C.textSec, ...
            'GridColor',C.border,'GridAlpha',0.4,'Box','on');
            
        hDiagLog = uicontrol('Parent',parent,'Style','listbox', ...
            'String',{'[等待训练...]'},'Units','pixels', ...
            'Position',[AX_X 10 AX_W AX_H_BOT], ...
            'FontName','SimHei','FontSize',9, ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.card, ...
            'Max',20);
            
        text(hDiagAx1,0.5,0.5,'训练完成后点击"异常度评分图"查看结果', ...
            'HorizontalAlignment','center','Color',C.textSec, ...
            'FontSize',12,'FontName','SimHei','Units','normalized');
            
        function doTrain()
            if isempty(state.fusedFeat)
                appendLog(hDiagLog,{'❌ 请先提取特征'}); return;
            end
            appendLog(hDiagLog,{'🤖 开始训练...'}); drawnow;
            setStatus('正在训练...', C.orange);
            
            try
                T = state.fusedFeat;
                [X, featNames] = helpers.selectNumericFeatureColumns(T,{'CycleNum'});
                X = helpers.fillmissingByMedian(X);
                validMask = all(isfinite(X),2) & ~ismissing(T.StageLabel);
                X = X(validMask,:);
                Tsub = T(validMask,:);
                Y = categorical(Tsub.StageLabel);
                
                varMask = std(X,0,1) > 0;
                X = X(:,varMask);
                featNames = featNames(varMask);
                if isempty(X), error('无可用特征列'); end
                
                Xz = zscore(X);
                
                % 异常度
                healthMask = Tsub.CycleNum == min(Tsub.CycleNum);
                if any(healthMask), mu0 = mean(Xz(healthMask,:),1,'omitnan');
                else, mu0 = mean(Xz,1,'omitnan'); end
                anomScore = sqrt(sum((Xz - mu0).^2, 2));
                
                classNames = categories(Y);
                classCounts = countcats(Y);
                minCount = min(classCounts);
                
                kStr = strtrim(get(hKFold,'String'));
                K = min(str2double(kStr), minCount);
                if isnan(K) || K < 2, K = 2; end
                
                nTrees = str2double(strtrim(get(hNTrees,'String')));
                if isnan(nTrees), nTrees = 100; end
                
                mdlIdx = get(hMdlType,'Value');
                mdlNames = {'Bag','AdaBoostM2','KNN','Tree'};
                mdlName = mdlNames{mdlIdx};
                
                r = struct();
                r.featureNames = featNames;
                r.sampleTable = Tsub;
                r.anomalyScore = anomScore;
                r.yTrue = Y;
                
                if numel(classNames) >= 2 && minCount >= 2 && size(X,1) >= 6
                    cvp = cvpartition(Y,'KFold',K);
                    if strcmp(mdlName,'KNN')
                        mdl = fitcknn(Xz,Y,'NumNeighbors',3);
                    elseif strcmp(mdlName,'Tree')
                        mdl = fitctree(Xz,Y);
                    else
                        mdl = fitcensemble(Xz,Y,'Method',mdlName, ...
                            'NumLearningCycles',nTrees);
                    end
                    cvMdl = crossval(mdl,'CVPartition',cvp);
                    yPred = kfoldPredict(cvMdl);
                    acc = mean(yPred == Y);
                    
                    r.model = mdl;
                    r.yPred = yPred;
                    r.confMat = confusionmat(Y,yPred);
                    r.accuracy = acc;
                    if strcmp(mdlName,'Bag') || strcmp(mdlName,'AdaBoostM2')
                        r.importance = predictorImportance(mdl);
                    else
                        r.importance = [];
                    end
                    
                    state.diagResult = r;
                    appendLog(hDiagLog,{ ...
                        sprintf('✅ 分类器：%s',mdlName), ...
                        sprintf('   K折CV准确率：%.2f%%', acc*100), ...
                        sprintf('   类别数：%d，样本总数：%d', numel(classNames), size(X,1))});
                    setStatus(sprintf('诊断完成，准确率 %.1f%%', acc*100), C.green);
                else
                    r.model = []; r.yPred = []; r.confMat = [];
                    r.accuracy = NaN; r.importance = [];
                    state.diagResult = r;
                    appendLog(hDiagLog,{'⚠ 类别或样本数不足，跳过分类，已完成异常度评分'});
                    setStatus('异常度评分完成（分类跳过）', C.orange);
                end
                showAnomalyInAx();
            catch ex
                appendLog(hDiagLog,{['❌ 训练失败: ' ex.message]});
                setStatus('训练失败', C.red);
            end
        end
        
        function showAnomalyInAx()
            if isempty(state.diagResult), return; end
            r = state.diagResult;
            cla(hDiagAx1,'reset');
            set(hDiagAx1,'Color',C.axBg,'XColor',C.textSec,'YColor',C.textSec, ...
                'GridColor',C.border,'GridAlpha',0.4,'Box','on');
            axes(hDiagAx1);
            scatter(r.sampleTable.CycleNum, r.anomalyScore, 60, ...
                double(r.yTrue), 'filled','MarkerEdgeColor','none');
            set(hDiagAx1,'XScale','log');
            xlabel(hDiagAx1,'Fatigue Cycles','Color',C.textPri);
            ylabel(hDiagAx1,'Anomaly Score','Color',C.textPri);
            title(hDiagAx1,'损伤异常度评分','Color',C.textPri,'FontName','SimHei');
            grid(hDiagAx1,'on');
        end
        
        function showAnomalyPlot()
            if isempty(state.diagResult)
                setStatus('请先训练模型', C.orange); return;
            end
            showAnomalyInAx();
        end
        
        function showConfMat()
            if isempty(state.diagResult) || isempty(state.diagResult.confMat)
                setStatus('无混淆矩阵数据', C.orange); return;
            end
            r = state.diagResult;
            figure('Name','混淆矩阵','Color','w');
            confusionchart(r.yTrue, r.yPred);
            title(sprintf('混淆矩阵 Accuracy=%.2f%%', r.accuracy*100));
        end
        
        function showImportance()
            if isempty(state.diagResult) || isempty(state.diagResult.importance)
                setStatus('无特征重要性数据（仅 Bag/AdaBoost 支持）', C.orange); return;
            end
            r = state.diagResult;
            [impSort, idx] = sort(r.importance,'descend');
            topN = min(15, numel(idx));
            figure('Name','特征重要性','Color','w');
            bar(impSort(1:topN));
            set(gca,'XTick',1:topN,'XTickLabel', ...
                cellstr(r.featureNames(idx(1:topN))),'XTickLabelRotation',45);
            ylabel('Importance'); title('Top 特征重要性'); grid on;
        end
        
        function doSaveModel()
            if isempty(state.diagResult)
                setStatus('无模型可保存', C.orange); return;
            end
            if isempty(state.cfg)
                try, state.cfg = config_project(); catch, end
            end
            outFile = '';
            if ~isempty(state.cfg), outFile = state.cfg.modelFile; end
            [f,p] = uiputfile('*.mat','保存诊断模型', outFile);
            if ischar(f) && ~isequal(f,0)
                result = state.diagResult; cfg = state.cfg; %#ok
                save(fullfile(p,f),'result','cfg','-v7.3');
                setStatus(['模型已保存: ' f], C.green);
                appendLog(hDiagLog,{['💾 模型保存: ' fullfile(p,f)]});
            end
        end
    end

%% ============================================================
%% 绘图子函数
%% ============================================================
    function plotGWOverlay(ax, selConds, sfSel, plSel, C)
        hold(ax,'on'); grid(ax,'on');
        cmap = lines(numel(selConds));
        cnt = 0;
        for ci = 1:numel(selConds)
            mask = state.guidedDS.ConditionName == selConds(ci);
            if ~strcmp(sfSel,'(全部)') && ~strcmp(sfSel,'(自动)')
                mask = mask & state.guidedDS.SignalField == string(sfSel);
            end
            if ~strcmp(plSel,'(全部)')
                mask = mask & state.guidedDS.PathLabel == string(plSel);
            end
            idx = find(mask,1,'first');
            if ~isempty(idx)
                t = state.guidedDS.TimeAxisUs{idx};
                s = state.guidedDS.ProcSignal{idx};
                plot(ax,t,s,'Color',cmap(ci,:),'LineWidth',1.2, ...
                    'DisplayName',char(selConds(ci)));
                cnt = cnt+1;
            end
        end
        if cnt > 0, legend(ax,'Location','best'); end
        xlabel(ax,'Time (μs)','Color',C.textPri);
        ylabel(ax,'Amplitude','Color',C.textPri);
        title(ax,'导波波形叠加','Color',C.textPri,'FontName','SimHei');
    end

    function plotGWSingle(ax, selConds, sfSel, plSel, C, mode)
        cond1 = selConds(1);
        mask = state.guidedDS.ConditionName == cond1;
        if ~strcmp(sfSel,'(全部)') && ~strcmp(sfSel,'(自动)')
            mask = mask & state.guidedDS.SignalField == string(sfSel);
        end
        idx = find(mask,1,'first');
        if isempty(idx)
            text(ax,0.5,0.5,'未找到该工况信号', ...
                'HorizontalAlignment','center','Color',C.orange, ...
                'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        sig = state.guidedDS.ProcSignal{idx};
        cfg2 = state.cfg;
        if isempty(cfg2), cfg2 = config_project(); end
        
        if strcmp(mode,'time')
            t = state.guidedDS.TimeAxisUs{idx};
            plot(ax,t,sig,'Color',C.accent,'LineWidth',1.3); hold(ax,'on');
            env = state.guidedDS.Envelope{idx};
            plot(ax,t,env,'--','Color',C.orange,'LineWidth',1.1, ...
                'DisplayName','Envelope');
            legend(ax,{'Signal','Envelope'},'Location','best');
            xlabel(ax,'Time (μs)','Color',C.textPri);
            ylabel(ax,'Amplitude','Color',C.textPri);
            title(ax,['时域波形 - ' char(cond1)],'Color',C.textPri,'FontName','SimHei');
        else
            N = numel(sig); fs = cfg2.fs;
            f = (0:N-1)/N * fs/1e3; % kHz
            SIG = abs(fft(sig));
            halfN = floor(N/2);
            plot(ax,f(1:halfN),SIG(1:halfN),'Color',C.green,'LineWidth',1.2);
            xlabel(ax,'Frequency (kHz)','Color',C.textPri);
            ylabel(ax,'Magnitude','Color',C.textPri);
            title(ax,['频谱 - ' char(cond1)],'Color',C.textPri,'FontName','SimHei');
        end
        grid(ax,'on');
    end

    function plotSTFT(ax, selConds, sfSel, C)
        cond1 = selConds(1);
        mask = state.guidedDS.ConditionName == cond1;
        if ~strcmp(sfSel,'(全部)') && ~strcmp(sfSel,'(自动)')
            mask = mask & state.guidedDS.SignalField == string(sfSel);
        end
        idx = find(mask,1,'first');
        if isempty(idx)
            text(ax,0.5,0.5,'未找到信号','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        sig = state.guidedDS.ProcSignal{idx};
        cfg2 = state.cfg; if isempty(cfg2), cfg2 = config_project(); end
        fs = cfg2.fs;
        win = hann(256); noverlap = 200; nfft = 512;
        [S,F,T2] = spectrogram(sig, win, noverlap, nfft, fs);
        % 频率转 kHz，时间转 μs
        imagesc(ax, T2*1e6, F/1e3, 20*log10(abs(S)+eps));
        axis(ax,'xy'); colormap(ax, jet);
        cb = colorbar(ax); cb.Color = C.textPri;
        xlabel(ax,'Time (μs)','Color',C.textPri);
        ylabel(ax,'Frequency (kHz)','Color',C.textPri);
        title(ax,['STFT 时频图 - ' char(cond1)],'Color',C.textPri,'FontName','SimHei');
    end

    function plotCWT(ax, selConds, sfSel, C)
        cond1 = selConds(1);
        mask = state.guidedDS.ConditionName == cond1;
        if ~strcmp(sfSel,'(全部)') && ~strcmp(sfSel,'(自动)')
            mask = mask & state.guidedDS.SignalField == string(sfSel);
        end
        idx = find(mask,1,'first');
        if isempty(idx)
            text(ax,0.5,0.5,'未找到信号','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        sig = state.guidedDS.ProcSignal{idx};
        cfg2 = state.cfg; if isempty(cfg2), cfg2 = config_project(); end
        fs = cfg2.fs;
        if exist('cwt','file') == 2
            [cfs,frequencies] = cwt(sig,'amor',fs);
            t = (0:numel(sig)-1)/fs * 1e6; % μs
            imagesc(ax, t, frequencies/1e3, abs(cfs));
            axis(ax,'xy'); colormap(ax, parula);
            cb = colorbar(ax); cb.Color = C.textPri;
            xlabel(ax,'Time (μs)','Color',C.textPri);
            ylabel(ax,'Frequency (kHz)','Color',C.textPri);
            title(ax,['CWT 小波时频图 - ' char(cond1)],'Color',C.textPri,'FontName','SimHei');
        else
            text(ax,0.5,0.5,'需要 Wavelet Toolbox（cwt函数）', ...
                'HorizontalAlignment','center','Color',C.orange, ...
                'FontSize',12,'FontName','SimHei','Units','normalized');
        end
    end

    function plotFiberOverlay(ax, selConds, C)
        hold(ax,'on'); grid(ax,'on');
        cmap = lines(numel(selConds));
        cnt = 0;
        for ci = 1:numel(selConds)
            mask = state.fiberDS.ConditionName == selConds(ci);
            idx = find(mask,1,'first');
            if ~isempty(idx)
                x = state.fiberDS.XAxisProc{idx};
                y = state.fiberDS.ProcProfile{idx};
                plot(ax,x,y,'Color',cmap(ci,:),'LineWidth',1.2, ...
                    'DisplayName',char(selConds(ci)));
                cnt = cnt + 1;
            end
        end
        if cnt > 0, legend(ax,'Location','best'); end
        xlabel(ax,'Fiber Axis','Color',C.textPri);
        ylabel(ax,'Profile Value','Color',C.textPri);
        title(ax,'光纤 Profile 叠加','Color',C.textPri,'FontName','SimHei');
    end

    function plotDamageTrend(ax, C)
        if isempty(state.guidedFeat)
            text(ax,0.5,0.5,'请先提取导波特征','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        gF = state.guidedFeat;
        T2 = groupsummary(gF,{'CycleNum','PathLabel'},'mean','GW_DamageIndex');
        hold(ax,'on'); grid(ax,'on');
        paths = unique(T2.PathLabel,'stable');
        cmap = lines(numel(paths));
        for pi = 1:numel(paths)
            sub = T2(T2.PathLabel == paths(pi),:);
            plot(ax,sub.CycleNum, sub.mean_GW_DamageIndex, '-o', ...
                'Color',cmap(pi,:),'LineWidth',1.2, ...
                'DisplayName',char(paths(pi)));
        end
        set(ax,'XScale','log');
        legend(ax,'Location','eastoutside');
        xlabel(ax,'Fatigue Cycles','Color',C.textPri);
        ylabel(ax,'Mean Damage Index','Color',C.textPri);
        title(ax,'导波路径损伤指标趋势','Color',C.textPri,'FontName','SimHei');
    end

    function runPCA(ax, T, C)
        [Xz,stageLabel] = prepFeatMatrix(T);
        if size(Xz,1) < 2
            text(ax,0.5,0.5,'样本不足','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        [~,score,~,~,explained] = pca(Xz);
        stages = categories(stageLabel);
        cmap = lines(numel(stages));
        hold(ax,'on'); grid(ax,'on');
        for si = 1:numel(stages)
            mask = stageLabel == stages{si};
            scatter(ax,score(mask,1),score(mask,2),60, ...
                cmap(si,:),'filled','DisplayName',stages{si});
        end
        legend(ax,'Location','best');
        xlabel(ax,sprintf('PC1 (%.1f%%)',explained(1)),'Color',C.textPri);
        ylabel(ax,sprintf('PC2 (%.1f%%)',explained(min(2,end))),'Color',C.textPri);
        title(ax,'融合特征 PCA','Color',C.textPri,'FontName','SimHei');
    end

    function runTSNE(ax, T, C)
        [Xz,stageLabel] = prepFeatMatrix(T);
        if size(Xz,1) < 4
            text(ax,0.5,0.5,'样本不足（需≥4）','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        if exist('tsne','file') ~= 2
            text(ax,0.5,0.5,'需要 Statistics and ML Toolbox（tsne）', ...
                'HorizontalAlignment','center','Color',C.orange, ...
                'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        perp = min(5,size(Xz,1)-1);
        Y2 = tsne(Xz,'NumDimensions',2,'Perplexity',perp);
        stages = categories(stageLabel);
        cmap = lines(numel(stages));
        hold(ax,'on'); grid(ax,'on');
        for si = 1:numel(stages)
            mask = stageLabel == stages{si};
            scatter(ax,Y2(mask,1),Y2(mask,2),60, ...
                cmap(si,:),'filled','DisplayName',stages{si});
        end
        legend(ax,'Location','best');
        xlabel(ax,'t-SNE 1','Color',C.textPri);
        ylabel(ax,'t-SNE 2','Color',C.textPri);
        title(ax,'融合特征 t-SNE','Color',C.textPri,'FontName','SimHei');
    end

    function runDamageTrendFull(ax, C)
        plotDamageTrend(ax, C);
    end

    function runCorrHeatmap(ax, T, C)
        numVars = T.Properties.VariableNames( ...
            varfun(@isnumeric,T,'OutputFormat','uniform'));
        numVars = numVars(1:min(20,numel(numVars)));
        Xmat = zeros(height(T),numel(numVars));
        for vi = 1:numel(numVars)
            col = T.(numVars{vi});
            if iscell(col), col = cell2mat(col); end
            Xmat(:,vi) = double(col);
        end
        Xmat(~isfinite(Xmat)) = 0;
        R = corr(Xmat,'rows','pairwise');
        imagesc(ax,R,[-1 1]);
        colormap(ax,redblue_colormap());
        cb = colorbar(ax); cb.Color = C.textPri;
        n = numel(numVars);
        shortNames = cellfun(@(s)s(max(1,end-6):end), numVars,'UniformOutput',false);
        set(ax,'XTick',1:n,'XTickLabel',shortNames,'XTickLabelRotation',45, ...
            'YTick',1:n,'YTickLabel',shortNames,'TickLength',[0 0]);
        title(ax,'特征相关性热图','Color',C.textPri,'FontName','SimHei');
    end

    function runBoxplot(ax, T, featName, C)
        if ~ismember(featName,T.Properties.VariableNames)
            text(ax,0.5,0.5,'未找到该特征列','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        col = T.(featName);
        if iscell(col), col = cell2mat(col); end
        col = double(col);
        labels = categorical(T.StageLabel);
        boxplot(ax,col,labels);
        set(ax,'XColor',C.textPri,'YColor',C.textPri);
        title(ax,['特征箱线图: ' featName],'Color',C.textPri,'FontName','SimHei');
        ylabel(ax,featName,'Color',C.textPri);
        xlabel(ax,'健康阶段','Color',C.textPri);
        grid(ax,'on');
    end

    function runDmgVsCycle(ax, T, C)
        if isempty(state.guidedFeat)
            text(ax,0.5,0.5,'请先提取特征','HorizontalAlignment','center', ...
                'Color',C.orange,'FontSize',12,'FontName','SimHei','Units','normalized');
            return;
        end
        gF = state.guidedFeat;
        stages = categories(categorical(gF.StageLabel));
        cmap = lines(numel(stages));
        hold(ax,'on'); grid(ax,'on');
        for si = 1:numel(stages)
            mask = string(gF.StageLabel) == string(stages{si});
            scatter(ax,gF.CycleNum(mask), gF.GW_DamageIndex(mask), ...
                40, cmap(si,:), 'filled','DisplayName',stages{si});
        end
        set(ax,'XScale','log');
        legend(ax,'Location','best');
        xlabel(ax,'Fatigue Cycles','Color',C.textPri);
        ylabel(ax,'GW Damage Index','Color',C.textPri);
        title(ax,'损伤指标 vs 工况数','Color',C.textPri,'FontName','SimHei');
    end

    function [Xz, stageLabel] = prepFeatMatrix(T)
        [rawX,~] = helpers.selectNumericFeatureColumns(T,{'CycleNum'});
        rawX = helpers.fillmissingByMedian(rawX);
        varMask = std(rawX,0,1) > 0;
        X = rawX(:,varMask);
        if isempty(X) || size(X,1) < 2
            Xz = zeros(height(T),1);
        else
            Xz = zscore(X);
        end
        stageLabel = categorical(T.StageLabel);
    end

%% ============================================================
%% 数据集构建（复用 step01/02 逻辑，避免重复）
%% ============================================================
    function ds = buildGuidedDataset(cfg2)
        matFiles = dir(fullfile(cfg2.guidedWaveDir, cfg2.guidedWavePattern));
        matFiles = matFiles(~ismember({matFiles.name}, cfg2.guidedWaveIgnore));
        if isempty(matFiles)
            error('未找到导波 MAT 文件：%s', cfg2.guidedWaveDir);
        end
        setupInfo = helpers.loadSetupInfo(cfg2.setupFile, cfg2);
        rows = {}; rowCount = 0;
        for k = 1:numel(matFiles)
            fp = fullfile(matFiles(k).folder, matFiles(k).name);
            condName = helpers.parseConditionFromFilename(matFiles(k).name);
            cycleNum = helpers.parseCycleNumber(condName);
            condStruct = helpers.loadConditionStruct(fp);
            sigFields = helpers.getSignalFields(condStruct);
            for i = 1:numel(sigFields)
                fn = sigFields{i};
                meta = helpers.parseSignalFieldName(fn);
                rawSig = double(condStruct.(fn));
                rawSig = rawSig(:).';
                proc = helpers.preprocessGuidedWave(rawSig, cfg2.fs, meta.frequencyKHz, cfg2);
                pathLabel = helpers.inferPathLabel(meta.signalId, setupInfo, cfg2);
                rowCount = rowCount+1;
                rows(rowCount,:) = {string(condName),double(cycleNum), ...
                    string(matFiles(k).name),string(fp),string(fn), ...
                    double(meta.signalId),double(meta.frequencyKHz),string(pathLabel), ...
                    {rawSig},{proc.signal},{proc.envelope},{proc.timeAxisUs}, ...
                    double(proc.energy),double(proc.peakAbs),double(proc.rmsValue)};
            end
        end
        if isempty(rows), error('导波数据集构建失败'); end
        ds = cell2table(rows,'VariableNames',{ ...
            'ConditionName','CycleNum','FileName','FilePath', ...
            'SignalField','SignalId','FrequencyKHz','PathLabel', ...
            'RawSignal','ProcSignal','Envelope','TimeAxisUs', ...
            'SignalEnergy','PeakAbs','RMSValue'});
        ds = sortrows(ds,{'CycleNum','SignalId','FrequencyKHz'});
        save(cfg2.guidedDatasetFile,'ds','cfg2','setupInfo','-v7.3');
    end

    function ds = buildFiberDataset(cfg2)
        files = dir(fullfile(cfg2.fiberDir, cfg2.fiberPattern));
        keep = true(numel(files),1);
        for i = 1:numel(files)
            nu = upper(files(i).name);
            for j = 1:numel(cfg2.fiberIgnoreContains)
                if contains(nu, upper(cfg2.fiberIgnoreContains{j}))
                    keep(i) = false;
                end
            end
        end
        files = files(keep);
        if isempty(files), error('未找到光纤 txt 文件：%s', cfg2.fiberDir); end
        rows = {}; rowCount = 0;
        for k = 1:numel(files)
            fp = fullfile(files(k).folder, files(k).name);
            condName = helpers.parseConditionFromFilename(files(k).name);
            cycleNum = helpers.parseCycleNumber(condName);
            fiber = helpers.readFiberTxt(fp, cfg2);
            proc = helpers.preprocessFiberProfile(fiber.xRaw, fiber.yRaw, cfg2);
            rowCount = rowCount+1;
            rows(rowCount,:) = {string(condName),double(cycleNum), ...
                string(files(k).name),string(fp), ...
                {fiber.xRaw},{fiber.yRaw},{proc.x},{proc.profile},{proc.gradient}, ...
                double(proc.energy),double(proc.rangeValue),double(proc.maxAbs)};
        end
        if isempty(rows), error('光纤数据集构建失败'); end
        ds = cell2table(rows,'VariableNames',{ ...
            'ConditionName','CycleNum','FileName','FilePath', ...
            'XAxis','RawProfile','XAxisProc','ProcProfile','Gradient', ...
            'ProfileEnergy','ProfileRange','ProfileMaxAbs'});
        ds = sortrows(ds,{'CycleNum'});
        save(cfg2.fiberDatasetFile,'ds','cfg2','-v7.3');
    end

%% ============================================================
%% 工具函数
%% ============================================================
    function setStatus(msg, col)
        set(hStatus,'String',msg,'ForegroundColor',col);
        drawnow;
    end

    function appendLog(hCtrl, msgs)
        cur = get(hCtrl,'String');
        if ischar(cur), cur = {cur}; end
        newLines = [cur; msgs(:)];
        set(hCtrl,'String',newLines,'Value',numel(newLines));
        drawnow;
    end

    function makeTitle(parent, titleStr, C, W, H) % <--- 在这里添加了 H 并在各个页面调用中传递了 H
        uicontrol('Parent',parent,'Style','text', ...
            'String',titleStr,'Units','pixels', ...
            'Position',[20 H-60 W-40 42], ...
            'FontName','SimHei','FontSize',18,'FontWeight','bold', ...
            'ForegroundColor',C.textPri,'BackgroundColor',C.bg, ...
            'HorizontalAlignment','left');
        uicontrol('Parent',parent,'Style','text','String','', ...
            'Units','pixels','Position',[20 H-66 W-40 2], ...
            'BackgroundColor',C.accent);
    end

    function makeCardTitle(parent, titleStr, C, x, y, w, h)
        uicontrol('Parent',parent,'Style','text', ...
            'String',titleStr,'Units','pixels', ...
            'Position',[x y w h], ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.accent,'BackgroundColor',C.bg, ...
            'HorizontalAlignment','left');
    end

    function hb = makeBtn(parent, label, bgcol, pos, callback, C)
        hb = uicontrol('Parent',parent,'Style','pushbutton', ...
            'String',label,'Units','pixels','Position',pos, ...
            'FontName','SimHei','FontSize',10,'FontWeight','bold', ...
            'ForegroundColor',C.textPri,'BackgroundColor',bgcol, ...
            'Callback',callback);
    end

    function cmap = redblue_colormap()
        % 简单红-白-蓝色图
        n = 64;
        r = [linspace(0.8,1,n/2), linspace(1,0.2,n/2)]';
        g = [linspace(0.2,1,n/2), linspace(1,0.2,n/2)]';
        b = [linspace(0.2,1,n/2), linspace(1,0.8,n/2)]';
        cmap = [r g b];
    end
end