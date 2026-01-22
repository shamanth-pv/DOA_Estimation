clc; clear; close all;

% Parameters
Fs = 400e3;             % Sampling Freq (400kHz)
Ts = 1/Fs;
T_total = 1e-3;
t = 0:Ts:T_total-Ts;

% USER ADJUSTABLE SETTINGS
delay = -100e-6;          % Time delay (10 us)
target_snr_db = 0.1;      % SNR in dB (Adjust this to test noise)
f_carrier = 40e3;       % 40 kHz
n_pulses = 8;
burst_duration = n_pulses * (1/f_carrier);

% Physical Parameters
d = 0.05;               % 5 cm spacing
c = 343;                % Speed of sound

% Signal Generation
t_start1 = 200e-6;
sig1_clean = zeros(size(t));
mask1 = (t >= t_start1) & (t < t_start1 + burst_duration - 1e-9);
sig1_clean(mask1) = 1.65 * (square(2*pi*f_carrier * (t(mask1) - t_start1)) + 1);

t_start2 = t_start1 + delay;
sig2_clean = zeros(size(t));
mask2 = (t >= t_start2) & (t < t_start2 + burst_duration - 1e-9);
sig2_clean(mask2) = 1.65 * (square(2*pi*f_carrier * (t(mask2) - t_start2)) + 1);

% Add Noise
sig_power = 1.65^2; 
noise_power = sig_power / (10^(target_snr_db/10));
noise_std_dev = sqrt(noise_power);
sig1 = sig1_clean + noise_std_dev * randn(size(sig1_clean));
sig2 = sig2_clean + noise_std_dev * randn(size(sig2_clean));

% MATLAB Cross-Correlation
[r, lags] = xcorr(sig2, sig1); 
[max_val, max_idx] = max(r);
tau = lags(max_idx) / Fs;

% Angle Calculation
if abs(tau) > (d/c)
    source_angle = NaN;
    angle_str = 'Invalid';
else
    source_angle = -asind((tau * c) / d);
    angle_str = sprintf('%.1f°', source_angle);
end

fprintf('--- MATLAB SIMULATION RESULTS ---\n');
fprintf('SNR: %d dB\n', target_snr_db);
fprintf('Calculated Delay: %.2f us\n', tau*1e6);
fprintf('Source Angle: %s\n', angle_str);

% FIGURE 1
f1 = figure('Name', 'MATLAB Simulation', 'NumberTitle', 'off', ...
            'Color','w', 'Position', [50, 50, 800, 900]);
sgtitle('Figure 1: MATLAB Simulation (Input)');

subplot(4,1,1);
plot(t*1e6, sig1, 'Color', [0 0.4470 0.7410]); hold on;
plot(t*1e6, sig1_clean, 'k:', 'LineWidth', 1); 
title(['Signal 1 (Left) - SNR ' num2str(target_snr_db) 'dB']);
ylabel('Voltage (V)'); grid on; xlim([0 500]); ylim([-1 4.5]);

subplot(4,1,2);
plot(t*1e6, sig2, 'Color', [0.8500 0.3250 0.0980]); hold on;
plot(t*1e6, sig2_clean, 'k:', 'LineWidth', 1);
title('Signal 2 (Right)');
ylabel('Voltage (V)'); grid on; xlim([0 500]); ylim([-1 4.5]);

subplot(4,1,3);
lag_time = lags / Fs * 1e6;
plot(lag_time, r, 'k', 'LineWidth', 1); hold on;
plot(tau*1e6, max_val, 'ro', 'MarkerFaceColor','r');
title(['Cross Correlation Peak at ' num2str(tau*1e6) '\mu s']);
xlabel('Lag (\mu s)'); ylabel('Strength'); grid on;

subplot(4,1,4);
hold on; box on;
plot([-2.5, 2.5], [0, 0], 'ks-', 'LineWidth', 2, 'MarkerFaceColor', 'k');
text(-3, -0.5, 'Left', 'HorizontalAlignment','center');
text(3, -0.5, 'Right', 'HorizontalAlignment','center');
if ~isnan(source_angle)
    R = 4;
    arrow_x = R * sind(source_angle); 
    arrow_y = R * cosd(source_angle);
    quiver(0, 0, arrow_x, arrow_y, 0, 'r', 'LineWidth', 3, 'MaxHeadSize', 0.5);
    text(arrow_x*1.1, arrow_y*1.1, angle_str, 'FontSize', 14, ...
        'Color', 'r', 'FontWeight','bold', 'HorizontalAlignment','center');
end
title('Estimated Source Direction');
xlim([-5 5]); ylim([-1 5]); axis equal; set(gca, 'XColor', 'none', 'YColor', 'none');
drawnow; % Force draw immediately

% Teensy

port = "COM3";
baud = 115200;

try
    fprintf('\nCONNECTING TO TEENSY\n');
    s = serialport(port, baud);
    configureTerminator(s, "LF"); 
    flush(s);
    
    % Send Header + Data
    write(s, [255, 255], "uint8");
    write(s, int8((sig1/3.3) * 127), "int8"); 
    write(s, int8((sig2/3.3) * 127), "int8");
    
    % Wait time
    max_wait = 10; 
    tic;
    stream_started = false;
    while toc < max_wait
        if s.NumBytesAvailable > 0
            stream_started = true;
            break; 
        end
        pause(0.01);
    end

    if stream_started
        disp('Reading Serial');
        
        rx_sig1 = [];
        rx_sig2 = [];
        rx_corr = [];
        
        % Read Loop
        tic;
        while toc < 5
            if s.NumBytesAvailable > 0
                line = readline(s);
                line = strtrim(line); 
                
                if endsWith(line, "SIG1_DATA_START")
                    dataStr = readline(s);
                    rx_sig1 = str2double(split(dataStr, ','));
                    disp(' -> Received Signal 1');
                elseif endsWith(line, "SIG2_DATA_START")
                    dataStr = readline(s);
                    rx_sig2 = str2double(split(dataStr, ','));
                    disp(' -> Received Signal 2');
                elseif endsWith(line, "CORR_DATA_START")
                    dataStr = readline(s);
                    rx_corr = str2double(split(dataStr, ','));
                    disp(' -> Received Correlation');
                elseif line == "--- DONE ---"
                    disp('Transmission Complete.');
                    break;
                end
            end
            pause(0.001);
        end
        
        % PLOT FIGURE 2
        if ~isempty(rx_sig1) && ~isempty(rx_corr)
            f2 = figure('Name', 'Teensy Hardware Result', 'NumberTitle', 'off', ...
                        'Color','w', 'Position', [900, 50, 800, 900]);
            sgtitle('Figure 2: Data Received from Teensy');
            
            subplot(4,1,1);
            stairs(rx_sig1, 'LineWidth', 1);
            title('Rx Signal 1 (Int8 Representation)'); grid on;
            ylim([-150 150]); ylabel('Raw Value');
            
            subplot(4,1,2);
            stairs(rx_sig2, 'r', 'LineWidth', 1);
            title('Rx Signal 2 (Int8 Representation)'); grid on;
            ylim([-150 150]); ylabel('Raw Value');
            
            subplot(4,1,3);
            lags = -(length(rx_sig1)-1) : (length(rx_sig1)-1);
            plot(lags, rx_corr, 'k', 'LineWidth', 1.5);
            
            % Calc Peak & Angle from Rx Data
            [max_val, max_idx] = max(rx_corr);
            actual_lag = lags(max_idx);
            rx_tau = actual_lag / Fs;
            rx_arg = (rx_tau * c) / d;
            if rx_arg > 1.0, rx_arg = 1.0; end
            if rx_arg < -1.0, rx_arg = -1.0; end
            rx_angle = -asind(rx_arg);
            angle_str_rx = sprintf('%.1f°', rx_angle);

            hold on; plot(actual_lag, max_val, 'ro');
            title(['Teensy Correlation | Peak Lag: ' num2str(actual_lag)]);
            grid on; xlabel('Lag (Samples)'); ylabel('Sum');
            
            subplot(4,1,4);
            hold on; box on;
            plot([-2.5, 2.5], [0, 0], 'ks-', 'LineWidth', 2, 'MarkerFaceColor', 'k');
            text(-3, -0.5, 'Left', 'HorizontalAlignment','center');
            text(3, -0.5, 'Right', 'HorizontalAlignment','center');
            
            R = 4;
            arrow_x = R * sind(rx_angle); 
            arrow_y = R * cosd(rx_angle);
            quiver(0, 0, arrow_x, arrow_y, 0, 'r', 'LineWidth', 3, 'MaxHeadSize', 0.5);
            text(arrow_x*1.1, arrow_y*1.1, angle_str_rx, 'FontSize', 14, ...
                'Color', 'r', 'FontWeight','bold', 'HorizontalAlignment','center');
            title('Teensy Calculated Direction');
            xlim([-5 5]); ylim([-1 5]); axis equal; set(gca, 'XColor', 'none', 'YColor', 'none');
            
        else
            disp('Error: Incomplete data received from Teensy.');
        end
    else
        disp('Timeout: Teensy did not respond.');
    end

catch ME
    disp('Error detected:');
    disp(ME.message);
end

clear s;