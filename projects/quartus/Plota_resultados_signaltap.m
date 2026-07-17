close all
clear all
m_fac = 454;

% Solicita o nome do arquivo CSV exportado do SignalTap
filename = 'output_files/stp1.csv'; % Substitua pelo nome correto do seu arquivo
%filename = 'low_high.csv'; % Substitua pelo nome correto do seu arquivo
%filename = 'high_low.csv'; % Substitua pelo nome correto do seu arquivo
%filename = 'm454.csv'; % Substitua pelo nome correto do seu arquivo
%filename = strcat('m',num2str(m_fac),'.csv'); % Substitua pelo nome correto do seu arquivo

disp(['Lendo arquivo: ', filename]);

% Lê o arquivo CSV ignorando possíveis cabeçalhos
opts = detectImportOptions(filename);
opts.DataLines = 2; % Pula a primeira linha se for cabeçalho
opts.VariableNamesLine = 1;

data = readtable(filename, opts);

disp('Arquivo lido com sucesso!');

% Exibe as primeiras linhas da tabela
head(data)

% Converte a tabela em variáveis separadas
times = data{:,1}; % Assume que a primeira coluna é o tempo

% Criar variáveis no workspace, convertendo colunas tipo cell para double
varNames = data.Properties.VariableNames;

for i = 2:length(varNames) % Começa na 2ª coluna porque a 1ª geralmente é tempo
    colData = data{:, i}; % Obtém a coluna

    % Se a coluna for do tipo cell, tenta converter para double
    if iscell(colData)
        colData = str2double(colData); % Converte string para número
    end
    
    % Salva a variável no workspace
    assignin('base', varNames{i}, colData);
end

disp('As variáveis foram carregadas no workspace!');


eng_truth = FPGA_Simulator_v1_PZC_sim_event_bt_12__0_(10:end);
snl_fpga = FPGA_Simulator_v1_PZC_sim_shaper_out_29__0_(10:end);
pzc_fpga = FPGA_Simulator_v1_PZC_sim_pzc_out_28__0_(10:end);
bt_mask_fpga = FPGA_Simulator_v1_PZC_sim_bt_mask_out(10:end);
pedestal_fpga = FPGA_Simulator_v1_PZC_sim_pedestal_out_12__0_(10:end);
shaper_clip_fpga = FPGA_Simulator_v1_PZC_sim_shaper_clip_11__0_(10:end);

shaper_uns = FPGA_Simulator_v1_PZC_sim_pzc_ped_track_pzc_zero_in_12__0_(10:end);

snl_fpga = snl_fpga(3:end)/(2^10);
shaper_clip_fpga = shaper_clip_fpga(3:end);
%snl_fpga = snl_fpga(3:end)/(1);

shaper_uns = shaper_uns(3:end);


%pzc_fpga = pzc_fpga(3:end)/(2^10*(m_fac+1));
pzc_fpga = pzc_fpga(3:end)/(1*(m_fac+1));

erro = [];

cont= 0;
for i = 1:length(pzc_fpga)-3
    if bt_mask_fpga(i) == 0
        cont = cont + 1;
        if (cont > 30 && bt_mask_fpga(i+3) == 0)
            erro = [erro, eng_truth(i) - pzc_fpga(i)];
        end
    else
        cont = 0;
    end
end

std_err = std(erro)
mean_err = mean(erro)

figure('DefaultAxesFontSize',24)
stairs(eng_truth,'g')
hold on;
%stairs(snl_fpga,'b')
stairs(pzc_fpga,'r')
%stairs(shaper_uns,'k')
stairs(shaper_clip_fpga,'k')
%stairs(bt_mask_fpga*2000,'k')
%legend('Generated Amplitude','Shaper Signal','PZC Signal','Shaper Clip');
legend('Generated Amplitude','PZC Signal','Shaper Clip');
xlabel('Sample');
ylabel('Amplitude [ADC Count]');
%xlim([0,1000]);
%ylim([-150,1600]);

% figure('DefaultAxesFontSize',24)
% hist(erro)
% hold on;
% % stairs(snl_fpga,'b')
% % stairs(pzc_fpga,'r')
% % stairs(bt_mask_fpga*2000,'k')
% % legend('Generated Amplitude','Shaper Signal','PZC Signal','Mask');
% xlabel('Error');
% title(strcat('M = ',num2str(m_fac)))
% ylabel('# Events');