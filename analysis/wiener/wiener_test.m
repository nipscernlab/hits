clc; clear; close all;

coeffs = [+0.05254051,  -0.14766654,  +0.38728372,  -0.91251163,  +1.68667686, -0.77512366,  +0.35378128,  -0.16148019,  +0.07330114];

T = readtable('../../projects/aurora/sim_pulsos_tb2.txt', 'FileType', 'text', 'Delimiter', '\t');

latencia = 3;   % ciclos do wiener_filter.v

%% Ideal filtering
% Shaper Clip (saida do HITS)
shaperClip = T.shaper_clip;

% Filtering using wiener
wienerIdeal = filter(coeffs, 1, shaperClip);

%% Quantization: modelo em inteiros (o que o Verilog calcula)
Q = 12;
coeffsQuant = round(coeffs * 2^Q);
wienerInt   = floor(filter(coeffsQuant, 1, shaperClip) / 2^Q);   % floor = >>> Q

%% FPGA Output, alinhada pela latencia
wienerOut = T.wiener_out(latencia+1:end);
n = length(wienerOut);

figure;
plot(wienerIdeal);
hold on;
plot(wienerOut)
legend('Ideal', 'FPGA Output')

erroQuant = wienerOut - wienerIdeal(1:n);   % ~ -0.5, faixa de +-1.3
erroFPGA  = wienerOut - wienerInt(1:n);     % deve ser zero depois do transitorio
fprintf('diferencas FPGA x modelo inteiro: %d\n', nnz(erroFPGA(20:end)));

