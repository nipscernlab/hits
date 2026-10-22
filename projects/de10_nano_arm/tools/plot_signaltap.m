close all
clear all
m_fac = 454;

% Name of the CSV file exported from SignalTap
filename = '../hardware/output_files/stp1.csv'; % replace with the name of your file
%filename = 'low_high.csv';
%filename = 'high_low.csv';
%filename = 'm454.csv';
%filename = strcat('m',num2str(m_fac),'.csv');

disp(['Reading file: ', filename]);

% Read the CSV file, skipping a possible header
opts = detectImportOptions(filename);
opts.DataLines = 2; % skip the first line if it is a header
opts.VariableNamesLine = 1;

data = readtable(filename, opts);

disp('File read.');

% Show the first lines of the table
head(data)

% Split the table into separate variables
times = data{:,1}; % the first column is assumed to be the time

% Create the variables in the workspace, converting cell columns to double
varNames = data.Properties.VariableNames;

for i = 2:length(varNames) % from the second column, since the first is usually time
    colData = data{:, i};

    % a cell column is converted to double
    if iscell(colData)
        colData = str2double(colData);
    end

    % store the variable in the workspace
    assignin('base', varNames{i}, colData);
end

disp('Variables loaded into the workspace.');


eng_truth = hits_reco_sim_event_bt_12__0_(10:end);
snl_fpga = hits_reco_sim_shaper_out_29__0_(10:end);
pzc_fpga = hits_reco_sim_pzc_out_28__0_(10:end);
bt_mask_fpga = hits_reco_sim_bt_mask_out(10:end);
pedestal_fpga = hits_reco_sim_pedestal_out_12__0_(10:end);
shaper_clip_fpga = hits_reco_sim_shaper_clip_11__0_(10:end);

shaper_uns = hits_reco_sim_pzc_ped_track_pzc_zero_in_12__0_(10:end);

snl_fpga = snl_fpga(3:end)/(2^10);
shaper_clip_fpga = shaper_clip_fpga(3:end);
%snl_fpga = snl_fpga(3:end)/(1);

shaper_uns = shaper_uns(3:end);


%pzc_fpga = pzc_fpga(3:end)/(2^10*(m_fac+1));
pzc_fpga = pzc_fpga(3:end)/(1*(m_fac+1));

err = [];

count = 0;
for i = 1:length(pzc_fpga)-3
    if bt_mask_fpga(i) == 0
        count = count + 1;
        if (count > 30 && bt_mask_fpga(i+3) == 0)
            err = [err, eng_truth(i) - pzc_fpga(i)];
        end
    else
        count = 0;
    end
end

std_err = std(err)
mean_err = mean(err)

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
% hist(err)
% hold on;
% % stairs(snl_fpga,'b')
% % stairs(pzc_fpga,'r')
% % stairs(bt_mask_fpga*2000,'k')
% % legend('Generated Amplitude','Shaper Signal','PZC Signal','Mask');
% xlabel('Error');
% title(strcat('M = ',num2str(m_fac)))
% ylabel('# Events');
