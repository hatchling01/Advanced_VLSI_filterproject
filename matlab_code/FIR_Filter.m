% Specifications
fs = 2; % Normalized frequency (Nyquist = 1, which is pi rad/sample)
f_pass = 0.2;   
f_stop = 0.23;  
attenuation = 80; 

% 1. Design filter
lpFilt = designfilt('lowpassfir', 'FilterOrder', 99, ...
    'PassbandFrequency', f_pass, 'StopbandFrequency', f_stop, ...
    'StopbandAttenuation', attenuation, 'SampleRate', fs);

% 2. Extract floating-point coefficients
b = lpFilt.Coefficients;

% 3. Quantize coefficients to 16-bit fixed-point Q1.15
num_bits = 16;
frac_bits = 15;
scale = 2^frac_bits;

bq_int = round(b * scale);                     % round to nearest
bq_int = min(max(bq_int, -2^(num_bits-1)), ...
                    2^(num_bits-1)-1);         % saturate
bq = bq_int / scale;                           % quantized coeffs back to decimal

% 4. Plot original and quantized responses together
[H, w]  = freqz(b, 1, 2048);
[Hq, ~] = freqz(bq, 1, 2048);

figure;
plot(w/pi, 20*log10(abs(H)+eps), 'b', 'LineWidth', 1.5); hold on;
plot(w/pi, 20*log10(abs(Hq)+eps), 'r--', 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Magnitude (dB)');
title('Original vs Quantized FIR Filter Response');
legend('Original (floating-point)', 'Quantized (Q1.15)');
xlim([0 1]);

% 5. Optional: also show in FVTool
fvtool(b, 1, bq, 1);
legend('Original (floating-point)', 'Quantized (Q1.15)');

% 6. Print coefficients
fprintf('Number of taps in the design: %d\n', length(b));
fprintf('Floating-point coefficients:\n');
fprintf('%f\n', b);

fprintf('\nQuantized integer coefficients (Q1.15):\n');
fprintf('%d\n', bq_int);

fprintf('\nQuantized decimal coefficients:\n');
fprintf('%f\n', bq);

% 7. Export floating-point taps
writematrix(b, 'filter_taps.csv');

% 8. Export quantized integer taps
writematrix(bq_int, 'filter_taps_quantized_q15.csv');