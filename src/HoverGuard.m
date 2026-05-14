classdef HoverGuard < matlab.apps.AppBase

    properties (Access = public)
        UIFigure        matlab.ui.Figure
        AltitudeAxes    matlab.ui.control.UIAxes
        ErrorAxes       matlab.ui.control.UIAxes
        FireButton      matlab.ui.control.Button
        ResetButton     matlab.ui.control.Button
        StartButton     matlab.ui.control.Button
        StatusLabel     matlab.ui.control.Label
        OvershootLabel  matlab.ui.control.Label
        SettlingLabel   matlab.ui.control.Label
        TitleLabel      matlab.ui.control.Label
        SubtitleLabel   matlab.ui.control.Label
        ResultsTable    matlab.ui.control.Table
        TableTitleLabel matlab.ui.control.Label
        WindForceLabel  matlab.ui.control.Label
        WindSlider      matlab.ui.control.Slider
    end

    properties (Access = private)
        t_sim
        y_sim
        e_sim
        timer_obj
        current_idx
        disturbance_fired
        disturbance_time
        max_altitude
        settled
        settling_time_val
        wind_force
        test_count
        table_data
    end

    methods (Access = private)

        function initSimulation(app, fire_dist)
            G  = tf([1],[1 2 5]);
            Kp = 10.2543; Ki = 13.1422; Kd = 1.9336;
            C  = pid(Kp, Ki, Kd);
            CL = feedback(C*G, 1);
            t  = 0:0.05:20;
            r  = ones(size(t));
            if fire_dist
                dist   = app.wind_force * (t >= app.disturbance_time);
                y_ref  = lsim(CL, r, t);
                y_dist = lsim(feedback(G,C), dist, t);
                y      = y_ref + y_dist;
            else
                y = lsim(CL, r, t);
            end
            app.t_sim             = t;
            app.y_sim             = y;
            app.e_sim             = r' - y;
            app.current_idx       = 1;
            app.max_altitude      = 0;
            app.settled           = false;
            app.settling_time_val = NaN;
        end

        function startTimer(app)
            if ~isempty(app.timer_obj) && isvalid(app.timer_obj)
                stop(app.timer_obj);
                delete(app.timer_obj);
            end
            app.timer_obj = timer(...
                'ExecutionMode','fixedRate',...
                'Period',0.05,...
                'TimerFcn',@(~,~) app.updatePlot());
            start(app.timer_obj);
        end

        function updatePlot(app)
            if app.current_idx > length(app.t_sim)
                stop(app.timer_obj);
                if app.disturbance_fired
                    app.logResult();
                end
                return;
            end
            idx   = app.current_idx;
            t_now = app.t_sim(1:idx);
            y_now = app.y_sim(1:idx);
            e_now = app.e_sim(1:idx);

            % Altitude plot
            cla(app.AltitudeAxes);
            plot(app.AltitudeAxes, t_now, y_now, 'c-', 'LineWidth', 2);
            hold(app.AltitudeAxes,'on');
            yline(app.AltitudeAxes, 1, 'w--', 'LineWidth', 1);
            if app.disturbance_fired
                xline(app.AltitudeAxes, app.disturbance_time, 'r--', 'LineWidth', 1.5);
            end
            hold(app.AltitudeAxes,'off');
            ylim(app.AltitudeAxes,[-0.2 1.5]);
            xlim(app.AltitudeAxes,[0 20]);

            % Error plot
            cla(app.ErrorAxes);
            plot(app.ErrorAxes, t_now, e_now, 'y-', 'LineWidth', 1.5);
            hold(app.ErrorAxes,'on');
            yline(app.ErrorAxes, 0, 'w--', 'LineWidth', 1);
            hold(app.ErrorAxes,'off');
            ylim(app.ErrorAxes,[-0.5 1.2]);
            xlim(app.ErrorAxes,[0 20]);

            % Overshoot
            app.max_altitude = max(app.max_altitude, y_now(end));
            overshoot        = max(0,(app.max_altitude - 1)*100);
            app.OvershootLabel.Text = sprintf('Overshoot: %.2f%%', overshoot);

            % Settling
            if ~app.settled && idx > 10
                recent = y_now(max(1,end-5):end);
                if all(abs(recent - 1) <= 0.02)
                    app.settled           = true;
                    app.settling_time_val = t_now(end);
                end
            end
            if ~isnan(app.settling_time_val)
                app.SettlingLabel.Text = sprintf('Settling: %.2fs', app.settling_time_val);
            else
                app.SettlingLabel.Text = 'Settling: measuring...';
            end

            % Status
            cy = y_now(end);
            if app.disturbance_fired && ...
               app.t_sim(idx) >= app.disturbance_time && ...
               app.t_sim(idx) <= app.disturbance_time + 0.5
                app.StatusLabel.Text      = '⚠ DISTURBED';
                app.StatusLabel.FontColor = [1 0.4 0];
            elseif abs(cy - 1) <= 0.02
                app.StatusLabel.Text      = '✓ STABLE';
                app.StatusLabel.FontColor = [0.2 1 0.4];
            else
                app.StatusLabel.Text      = '↺ RECOVERING';
                app.StatusLabel.FontColor = [1 1 0];
            end

            app.current_idx = app.current_idx + 5;
            drawnow limitrate;
        end

        function logResult(app)
            overshoot = max(0,(app.max_altitude - 1)*100);
            if isnan(app.settling_time_val)
                s_str  = 'N/A';
                st_str = '✗ Fail';
            elseif app.settling_time_val <= 3.0
                s_str  = sprintf('%.2fs', app.settling_time_val);
                st_str = '✓ Pass';
            else
                s_str  = sprintf('%.2fs', app.settling_time_val);
                st_str = '✗ Fail';
            end
            app.test_count = app.test_count + 1;
            new_row        = {app.test_count, ...
                              sprintf('%.1fN', app.wind_force), ...
                              sprintf('%.2f%%', overshoot), ...
                              s_str, st_str};
            app.table_data          = [app.table_data; new_row];
            app.ResultsTable.Data   = app.table_data;
        end

    end

    methods (Access = public)

        function app = HoverGuard

            % ── Figure ──────────────────────────────────────────
            app.UIFigure = uifigure(...
                'Name','HoverGuard — Drone Altitude Control',...
                'Position',[50 50 1150 700],...
                'Color',[0.08 0.08 0.12]);

            % ── Title ───────────────────────────────────────────
            app.TitleLabel = uilabel(app.UIFigure,...
                'Text','🚁  HoverGuard',...
                'Position',[20 655 320 38],...
                'FontSize',26,'FontWeight','bold',...
                'FontColor',[0.4 0.8 1]);

            app.SubtitleLabel = uilabel(app.UIFigure,...
                'Text','Autonomous Wind-Rejection Altitude Control',...
                'Position',[20 638 420 18],...
                'FontSize',11,'FontColor',[0.6 0.6 0.6]);

            % ── Altitude Axes ────────────────────────────────────
            app.AltitudeAxes = uiaxes(app.UIFigure,...
                'Position',[20 360 590 265],...
                'Color',[0.12 0.12 0.18],...
                'XColor','w','YColor','w');
            title(app.AltitudeAxes,'Altitude (m)','Color','w');
            xlabel(app.AltitudeAxes,'Time (s)');
            ylabel(app.AltitudeAxes,'Altitude (m)');
            grid(app.AltitudeAxes,'on');

            % ── Error Axes ───────────────────────────────────────
            app.ErrorAxes = uiaxes(app.UIFigure,...
                'Position',[20 70 590 265],...
                'Color',[0.12 0.12 0.18],...
                'XColor','w','YColor','w');
            title(app.ErrorAxes,'Error Signal','Color','w');
            xlabel(app.ErrorAxes,'Time (s)');
            ylabel(app.ErrorAxes,'Error');
            grid(app.ErrorAxes,'on');

            % ── RIGHT PANEL ──────────────────────────────────────
            % Status  (top of panel)
            app.StatusLabel = uilabel(app.UIFigure,...
                'Text','● READY',...
                'Position',[635 638 200 38],...
                'FontSize',20,'FontWeight','bold',...
                'FontColor',[0.2 1 0.4],...
                'HorizontalAlignment','center');

            % Overshoot
            app.OvershootLabel = uilabel(app.UIFigure,...
                'Text','Overshoot: --',...
                'Position',[635 600 200 28],...
                'FontSize',13,...
                'FontColor',[0.9 0.9 0.9],...
                'HorizontalAlignment','center');

            % Settling
            app.SettlingLabel = uilabel(app.UIFigure,...
                'Text','Settling: --',...
                'Position',[635 570 200 28],...
                'FontSize',13,...
                'FontColor',[0.9 0.9 0.9],...
                'HorizontalAlignment','center');

            % Divider space then Wind label
            app.WindForceLabel = uilabel(app.UIFigure,...
                'Text','Wind Force: 0.5 N',...
                'Position',[635 530 200 25],...
                'FontSize',12,'FontWeight','bold',...
                'FontColor',[1 0.65 0.1],...
                'HorizontalAlignment','center');

            % Slider — give it room BELOW for tick labels
            app.WindSlider = uislider(app.UIFigure,...
                'Position',[640 505 190 3],...
                'Limits',[0.5 5.0],...
                'Value',0.5,...
                'MajorTicks',[0.5 1 2 3 4 5],...
                'FontColor','w',...
                'ValueChangedFcn',@(sld,~) app.sliderMoved(sld.Value));

            % Buttons — start well below the slider tick labels
            app.StartButton = uibutton(app.UIFigure,...
                'Text','▶  Start Simulation',...
                'Position',[635 435 200 45],...
                'FontSize',13,'FontWeight','bold',...
                'BackgroundColor',[0.1 0.55 0.25],...
                'FontColor','w',...
                'ButtonPushedFcn',@(~,~) app.startSimulation());

            app.FireButton = uibutton(app.UIFigure,...
                'Text','🌬  Fire Wind Gust',...
                'Position',[635 378 200 45],...
                'FontSize',13,'FontWeight','bold',...
                'BackgroundColor',[0.75 0.15 0.15],...
                'FontColor','w',...
                'ButtonPushedFcn',@(~,~) app.fireDisturbance());

            app.ResetButton = uibutton(app.UIFigure,...
                'Text','↺  Reset All',...
                'Position',[635 320 200 42],...
                'FontSize',12,...
                'BackgroundColor',[0.2 0.35 0.65],...
                'FontColor','w',...
                'ButtonPushedFcn',@(~,~) app.resetSimulation());

            % Instructions
            uilabel(app.UIFigure,...
                'Text',sprintf('HOW TO USE:\n1. Press Start\n2. Adjust wind slider\n3. Fire Wind Gust\n4. Results log automatically'),...
                'Position',[635 195 200 115],...
                'FontSize',11,...
                'FontColor',[0.5 0.5 0.5],...
                'VerticalAlignment','top');

            % ── TABLE PANEL ──────────────────────────────────────
            app.TableTitleLabel = uilabel(app.UIFigure,...
                'Text','📊  Wind Gust Test Log',...
                'Position',[858 655 240 28],...
                'FontSize',13,'FontWeight','bold',...
                'FontColor',[0.4 0.8 1]);

            app.ResultsTable = uitable(app.UIFigure,...
                'Position',[855 70 270 570],...
                'ColumnName',{'#','Wind','Overshoot','Settling','Status'},...
                'ColumnWidth',{28 52 72 62 54},...
                'RowName',{},...
                'FontSize',11);

            % ── Init state ───────────────────────────────────────
            app.disturbance_fired = false;
            app.disturbance_time  = 0;
            app.wind_force        = 0.5;
            app.test_count        = 0;
            app.table_data        = {};
            app.t_sim             = [];
        end

        function sliderMoved(app, val)
            app.wind_force          = val;
            app.WindForceLabel.Text = sprintf('Wind Force: %.1f N', val);
        end

        function startSimulation(app)
            app.disturbance_fired = false;
            app.disturbance_time  = 0;
            initSimulation(app, false);
            startTimer(app);
        end

        function fireDisturbance(app)
            if isempty(app.t_sim), return; end
            app.disturbance_fired = true;
            app.disturbance_time  = app.t_sim(...
                min(app.current_idx, length(app.t_sim)));
            initSimulation(app, true);
            startTimer(app);
        end

        function resetSimulation(app)
            if ~isempty(app.timer_obj) && isvalid(app.timer_obj)
                stop(app.timer_obj);
            end
            cla(app.AltitudeAxes);
            cla(app.ErrorAxes);
            app.StatusLabel.Text      = '● READY';
            app.StatusLabel.FontColor = [0.2 1 0.4];
            app.OvershootLabel.Text   = 'Overshoot: --';
            app.SettlingLabel.Text    = 'Settling: --';
            app.disturbance_fired     = false;
            app.t_sim                 = [];
            app.test_count            = 0;
            app.table_data            = {};
            app.ResultsTable.Data     = {};
        end

    end
end