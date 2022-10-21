close all
clear all

%% Need these folders for the audio files
addpath(genpath('1'))
addpath(genpath('2'))
addpath(genpath('3'))
addpath(genpath('4'))

%% Import the SPIN target words file
% targetWordList = readtable("SPIN_test_scoresheets.xlsx","Range","A1:C401");
% targetWordList.Carrier = [];
%% Create a fixation cross
% % Create the fixation cross
% figure('color','k')
% set(gcf,'Position',[-500 500 400 300],'MenuBar', 'None','WindowState','fullscreen')
% ax = gca;
% ax.XAxisLocation = 'origin';
% ax.YAxisLocation = 'origin';
% scatter(0,0,'+','LineWidth',100,'MarkerEdgeColor','w')
% set(gca, 'Color','k', 'XColor','k', 'YColor','k')
%% Initialize LSL stream to transmit markers
addpath(genpath('liblsl-Matlab')) % Need this folder to create LSL stream

% Load the library first so that lsl functions are available to us
lib = lsl_loadlib();

% Let's open up a stream outlet to send the markers to
% First we'll need info about the stream
%   Define the variables separately and keep the original arguments in the
%   lsl_streaminfo function for future reference
name = 'CSTMarkers';
type = 'Markers';
channelcount = 1; %Only sending markers
samplingrate = 0; %No regular sampling rate
channelformat = 'cf_string'; %We're sending strings
sourceid = '1234'; %Testing a unique source ID in case anything crashes
info = lsl_streaminfo(lib,name,type,channelcount,samplingrate,channelformat,sourceid);

%Let's open up that stream outlet
outlet = lsl_outlet(info);
%% Initialize Psychtoolbox
% Running on PTB-3? Abort otherwise.
AssertOpenGL;

%% Initialize keyboard stuff
% In this experiment, the only keyboard input that we want is from the
% spacebar
KbName('UnifyKeyNames');
responseKeys = {'space'};
KbCheckList = [KbName('space'),KbName('ESCAPE')];
for i = 1:length(responseKeys)
    KbCheckList = [KbName(responseKeys{i}),KbCheckList];
end
% this makes sure that the only 'legal' keypresses are from the space bar
% and the escape key (in case we need to force-quit)
RestrictKeysForKbCheck(KbCheckList);

%% Initialize sound stuff
% This routine loads the PsychPortAudio sound driver for high-precision,
% low-latency, multi-channel sound playback and recording.
%   Set the argument to '1' to run in low latency mode
InitializePsychSound(1)

device = []; %The default soundcard
mode = []; %Mode of operation. Default is audio playback only
reqlatencyclass = 1;  %The default is 1. Try to get the lowest latency
%that is possible under the constraint of reliable playback, freedom of choice
%for all parameters and interoperability with other applications.
freq = []; %Requested playback/capture rate in samples per second (Hz). Defaults to a value that depends on the
%requested latency mode
nrChannels = 2; %Default for stereo sound
bufferSize = []; %Best left alone -- let it default
suggestedLatency = []; %Best left alone -- let it default
pahandle = PsychPortAudio('Open', device, mode, reqlatencyclass, freq, nrChannels, bufferSize, suggestedLatency);

% Get frequency for playback:
s = PsychPortAudio('GetStatus', pahandle);
freq = s.SampleRate;

%% Take a brief pause -- need some user input from experimenters to initiate the experiment
% Ask for the PID
promptPID = {'Enter PID:'};
dlgtitlePID = 'PID';
dims = [1 35];
definputPID = {'000'};
PID = inputdlg(promptPID,dlgtitlePID,dims,definputPID);

% Ask for the counterbalance order
while (1)
    promptOrder = {'Enter the counterbalance order (separated by a space):'};
    dlgtitleOrder = 'Order of Conditions';
    dims = [1 35];
    definputOrder = {'0 0 0 0'};
    Order = inputdlg(promptOrder,dlgtitleOrder,dims,definputOrder);

    % Check to see if counterbalance order is correctly formatted
    % We're checking for three conditions: 1) There are 4 numbers, 2) There are
    % no repeated numbers, and 3) All numbers are between 1 and 4.
    conditionOrder = str2num(Order{1});

    %If conditions are met, continue with the code
    if length(conditionOrder) == 4 && length(conditionOrder) == length(unique(conditionOrder))...
            && all(conditionOrder >=1 & conditionOrder <=4)
        break
    else %Otherwise, let user know there was an error and ask them to input the order again
        err = errordlg('Formatting Error','Input Error'); %
        waitfor(err)
    end
end

% Instruct the user to begin setting up the fNIRS equipment
message = ["Set up the fNIRS equipment."; "Don't forget to import the LSL markers titled 'SPINMarkers'.";" ";
    "Press 'OK' when setup is done."];
f = msgbox(message,'Setup Time');
waitfor(f)

%Confirm with the user that experimental setup is ready. Pressing OK wil
%begin the experiment
message = ["Experimental setup is ready. Press the 'Record' button in  OxySoft.";" ";
    "Press 'OK' when fNIRS data is being recorded."];
g = msgbox(message,'Record fNIRS');
waitfor(g)

message = ["The experiment will now begin.";" ";
    "Press 'OK' to start the experiment."];
h = msgbox(message,'Experiment Ready');
waitfor(h)
clc
%% Now for the experiment. This code will run 4 times since we have 4 conditions.
%Let's first get our current directory (the audio files for the experiments
%should be stored in 4 different folders). Make sure that these 4 folderes
%are in the same folder as this code.
currentDir = pwd;
for k = 1:4
    %% Prepare the audio files and store them to create a "playlist"
    filepath = fullfile(currentDir,num2str(conditionOrder(k)));
    files = dir(fullfile(filepath,'*.wav')); % Get the name of all folders in file

    buffer = [];
    % This will grow in size according to the number of buffers that are created
    for i = 1:size(files,1)
        % Read the audio files into MATLAB
        fileName = fullfile(filepath,files(i).name);
        [audiodata, infreq] = psychwavread(fileName);

        % Check to see if freq of audio file and freq of playback the same
        if infreq ~= freq % If they're not, do some resampling
            audiodata = resample(audiodata, freq, infreq); %Resample to 48kHz
            audiodata = audiodata';
        end
        audioDuration(i) = length(audiodata)/freq;

        % We want to playback in stereo, which means we need two rows of the audio
        % signal
        if size(audiodata,1) < 2
            audiodata = repmat(audiodata,2,1);
        end

        buffer(end+1) = PsychPortAudio('CreateBuffer', [], audiodata); %Create a buffer and store the audio clip
    end

    nfiles = length(buffer);
    %% Let's start loading the files into a buffer and playing the stimuli
    % But first, define some variables to be used by PsychPortAudio
    repetitions = []; %Default is 1
    when = []; %Default to 0 (start immediately)
    waitForStart = 1; %If ‘waitForStart’ is set to non-zero value, ie if PTB should
    % wait for sound onset, then the optional return argument ‘startTime’ will contain
    % an estimate of when the first audio sample hit the speakers, i.e., the real
    % start time.

    bufferCnt = 1; % Initialize a counter for the number of buffers we're using

    %Collect a 20 sec baseline before each condition
    disp(['Starting 20 sec baseline period...']);
    disp(' ')
    outlet.push_sample({['Baseline cond',num2str(conditionOrder(k))]}); % Send the trigger to the outlet
    WaitSecs(20); %20 second baseline
    disp(['Baseline done.']);
    disp(' ')

    while(bufferCnt <= nfiles) %This loop will go on until we've gone through each buffer's audio
        s = PsychPortAudio('GetStatus', pahandle);
        if s.Active == 0
            %% Fill buffers to play audio
            PsychPortAudio('FillBuffer', pahandle, buffer(bufferCnt));

            %% Play the audio and send trigger to Oxysoft
            % Right before the sentence begins, send the trigger
            disp(['Playing Condition ', num2str(conditionOrder(k)), ' Passage ',num2str(bufferCnt),'...']);
            outlet.push_sample({['Cond', num2str(conditionOrder(k)), '-Passage',num2str(bufferCnt)]}); % Send the trigger to the outlet

            % Play the audio
            PsychPortAudio('Start', pahandle, [], 0, 1);
            WaitSecs(audioDuration(bufferCnt)); % Wait for the audio to finish playing before proceeding with rest of code

            %% Participant response
            % There is no input from the participant; they will respond
            % vocally. They have 6 seconds to respond
            WaitSecs(6); %6 seconds

            %% Next passage
            % The next passage will be played after a 20 sec silent period.
            if bufferCnt == nfiles
                disp(['Condition ' num2str(conditionOrder(k)),' done.'])
                disp(' ')
                break
            else
                disp('Silent baseline (20 sec)')
                outlet.push_sample({'Silent Start'});
                disp(' ')
                WaitSecs(20); %20 seconds
            end

            %% Time to move on to the next audio file
            bufferCnt = bufferCnt + 1;
        end
    end
end
% Close the audio device:
PsychPortAudio('Close', pahandle);

% %% Stimuli is done. Let's summarize some information in an excel file
% % Put the PID and counterbalance order at the very top.
% % We'll also include the following information for each condition:
% % 1) The audio stimuli order
% % 2) The participant's response time
% % 3) The jitter times between each stimuli
% outputName = ['PID_' PID{1} '_summary.xlsx'];
% headerInfo = {'PID:' str2num(PID{1}); 'Counterbalance Order:' Order{1}};
% writecell(headerInfo, outputName);
%
% excelRanges = {'A' 'E' 'I' 'M'};
% for j = 1:4
%     tableInfo = {'Condition:' conditionOrder(j)};
%     writecell(tableInfo, outputName, 'Range', strcat(excelRanges{j},num2str(4)));
%     Audio_Order = summary(j).Audio_Order;
%     %     Response_Time = summary(j).Response_Time;
%     Target_Word = summary(j).Target_Word;
%     Jitter_Time = summary(j).Jitter_Times';
%     T = table(Audio_Order, Target_Word, Jitter_Time);
%     writetable(T,outputName,'Range',strcat(excelRanges{j},num2str(5)));
% end
