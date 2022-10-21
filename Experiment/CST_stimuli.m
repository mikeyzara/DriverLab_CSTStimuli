close all
clear all

%% Need these folders for the audio files
addpath(genpath('1'))
addpath(genpath('2'))
addpath(genpath('3'))
addpath(genpath('4'))
addpath(genpath('Practice Sentences'))
addpath(genpath('Phase 5 Practice'))

%% Initialize LSL stream to transmit markers
addpath(genpath('liblsl-Matlab-master')) % Need this folder to create LSL stream

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
message = ["Set up the fNIRS equipment."; "Don't forget to import the LSL markers titled 'CSTMarkers'.";" ";
    "Press 'OK' when setup is done."];
f = msgbox(message,'Setup Time');
waitfor(f)

%% Phase 2 and 3 of experiment -- Practice Sentences
currentDir = pwd; %Get current directory
practicePath = fullfile(currentDir,'Practice Sentences','Phase 2 and 3 - Signal'); %Directory that holds practice sentence audio files
practiceFiles_s = dir(fullfile(practicePath,'*.wav')); %List of files in above directory
practiceFiles_n = dir(fullfile(currentDir,'Practice Sentences','Phase 2 and 3 - Noise','*.wav')); %List of files in noise folder

clc
disp('Starting Phases 2 and 3 of Experiment (Practice Sentences)')
while(1)
    % Select the file
    [audioIdx,tfaudio] = listdlg('PromptString',{'Select a practice sentence.',...
        'Only one file can be selected at a time.',''},...
        'SelectionMode','single','ListString',{practiceFiles_s.name});

    if tfaudio == 1 %A selection was made
        practiceSentences(audioIdx,practiceFiles_s,practiceFiles_n,freq);

        % User input: continue practice or move on to Phase 5?
        phase = questdlg('Continue Practice Phase or move on to Experimental Phase?','','Practice','Phase 5','Practice');
        if strcmp(phase,'Phase 5')
            break;
        elseif strcmp(phase,'Practice')
            message = ["Continuing Practice Phase.";" ";
                "Press 'OK' to select a practice sentence."];
            q = msgbox(message);
            waitfor(q)
        else
            error('No choice selected.')
        end
    else
        error('Cancelled program.')
    end
end

%% Phase 5 -- Experiment
% Participant will listen to additional practice sentences before the actual
% experiment. Order of sentences will change depending on participant's
% counterbalance.
message = ["PHASE 5: One more practice session.";" ";
    "Press 'OK' to start the Phase 5 practice session."];
h = msgbox(message,'Phase 5');
waitfor(h)

% Store the file paths for the experimental practice sentences. The first
% row is the path for 0SNR (col1: signal, col2: noise) and the second row
% is the path for +4SNR (col1: signal, col2: noise).
experimentPractice{1,1} = fullfile(currentDir,'Phase 5 Practice','Phase 5 - 0SNR - Signal');
experimentPractice{1,2} = fullfile(currentDir,'Phase 5 Practice','Phase 5 - 0SNR - Noise');
experimentPractice{2,1} = fullfile(currentDir,'Phase 5 Practice','Phase 5 - +4SNR - Signal');
experimentPractice{2,2} = fullfile(currentDir,'Phase 5 Practice','Phase 5 - +4SNR - Noise');

% Check which condition is played first
if conditionOrder(1) == 1 || conditionOrder(1) == 2 %If either of these conditions are the first to be presented,
    snrIdx = [1 2]; % 0SNR presented first
    disp('Practicing HARD condition (0SNR) first');
else
    snrIdx = [2 1]; % otherwise, +4SNR is presented first
    disp('Practicing EASY condition (+4SNR) first');
end

% Present the practice sentences
%   The filepaths:
expPractice_s = dir(fullfile(experimentPractice{snrIdx(1),1},'*.wav'));
expPractice_n = dir(fullfile(experimentPractice{snrIdx(1),2},'*.wav'));
while (1)
    % Select the file
    [audioIdx,tfaudio] = listdlg('PromptString',{'Select a practice sentence.',...
        'Only one file can be selected at a time.',''},...
        'SelectionMode','single','ListString',{expPractice_s.name});

    if tfaudio == 1 %A selection was made
        practiceSentences(audioIdx,expPractice_s,expPractice_n,freq);

        % User input: continue practice or move on to experiment?
        phase = questdlg('Continue Practice Phase or move on to Experimental Phase?','','Practice','Experiment','Practice');
        if strcmp(phase,'Experiment')
            break;
        elseif strcmp(phase,'Practice')
            message = ["Continuing Practice Phase.";" ";
                "Press 'OK' to select a practice sentence."];
            q = msgbox(message);
            waitfor(q)
        else
            error('No choice selected.')
        end
    else
        error('Program cancelled.')
    end
end

%Confirm with the user that experimental setup is ready. Pressing OK will
%begin the experiment
message = ["Experimental setup is ready. Press the 'Record' button in OxySoft.";" ";
    "Press 'OK' when fNIRS data is being recorded."];
g = msgbox(message,'Record fNIRS');
waitfor(g)

message = ["The experiment will now begin.";" ";
    "Press 'OK' to start the experiment."];
h = msgbox(message,'Experiment Ready');
waitfor(h)

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

clc %Clear the Command Window

%% Now for the experiment. This code will run 4 times since we have 4 conditions.
%Let's first get our current directory (the audio files for the experiments
%should be stored in 4 different folders). Make sure that these 4 folderes
%are in the same folder as this code.
currentDir = pwd;
for k = 1:4
    if k == 3 %Start of the second half of experiment -- will do another practice session with the other set of sentences
        message = ["Moving on to the second half of the experiment. We will now proceed with the second experimental practice session.";" ";
            "Press 'OK' to start the practice sentence."];
        q = msgbox(message);
        waitfor(q)
        expPractice_s = dir(fullfile(experimentPractice{snrIdx(2),1},'*.wav'));
        expPractice_n = dir(fullfile(experimentPractice{snrIdx(2),2},'*.wav'));
        while (1)
            % Select the file
            [audioIdx,tfaudio] = listdlg('PromptString',{'Select a practice sentence.',...
                'Only one file can be selected at a time.',''},...
                'SelectionMode','single','ListString',{expPractice_s.name});

            if tfaudio == 1 %A selection was made
                practiceSentences(audioIdx,expPractice_s,expPractice_n,freq);

                % User input: continue practice or move on to experiment?
                phase = questdlg('Continue Practice Phase or move on to Experimental Phase?','','Practice','Experiment','Practice');
                if strcmp(phase,'Experiment')
                    break;
                else
                    message = ["Continuing Practice Phase.";" ";
                        "Press 'OK' to select a practice sentence."];
                    q = msgbox(message);
                    waitfor(q)
                end
            end
        end
    end
    %% Prepare the audio files and store them to create a "playlist"
    filepath = fullfile(currentDir,num2str(conditionOrder(k)));
    % The signal files
    sigPath = fullfile(currentDir,num2str(conditionOrder(k)),'signal');
    sigFiles = dir(fullfile(sigPath,'*.wav')); % Get the name of all signal files

    % The noise files
    noisePath = fullfile(currentDir,num2str(conditionOrder(k)),'noise');
    noiseFiles = dir(fullfile(noisePath,'*.wav')); % Get the name of all noise files

    buffer = [];% This will grow in size according to the number of buffers that are created

    for i = 1:size(sigFiles,1)
        % Read the audio files into MATLAB
        fsignal = fullfile(filepath,'signal',sigFiles(i).name);
        fnoise = fullfile(filepath,'noise',noiseFiles(i).name);
        [signalData, infreq1] = psychwavread(fsignal);
        [noiseData, infreq2] = psychwavread(fnoise);


        % Check to see if freq of audio file and freq of playback the same
        if infreq1 ~= freq % If they're not, do some resampling
            signalData = resample(signalData, freq, infreq1); %Resample to 48kHz
        end

        if infreq2 ~= freq % If they're not, do some resampling
            noiseData = resample(noiseData, freq, infreq2); %Resample to 48kHz
        end

        % Make both files the same length
        if length(signalData) > length(noiseData) %If signal is longer than noise
            signalData = signalData(1:length(noiseData));
        elseif length(signalData) < length(noiseData) %If noise is longer than signal
            noiseData = noiseData(1:length(signalData));
        end

        % Playback will be in stereo. One channel is signal while the other
        % is noise.
        audiodata = [signalData'; noiseData'];
        audioDuration(i) = length(audiodata)/freq;

        buffer(end+1) = PsychPortAudio('CreateBuffer', [], audiodata); %Create a buffer and store the audio clip
    end

    nfiles = length(buffer); %There should be 4 files -- one for each topic/passage

    %% Let's start loading the files into a buffer and playing the stimuli
    % But first, define some variables to be used by PsychPortAudio
    repetitions = []; %Default is 1
    when = []; %Default to 0 (start immediately)
    waitForStart = 1; %If ‘waitForStart’ is set to non-zero value, ie if PTB should
    % wait for sound onset, then the optional return argument ‘startTime’ will contain
    % an estimate of when the first audio sample hit the speakers, i.e., the real
    % start time.

    bufferCnt = 1; % Initialize a counter for the number of buffers we're using

    message = ["The condition will now begin.";" ";
        "Press 'OK' to start the condition."];
    h = msgbox(message,'Condition Ready');
    waitfor(h)

    clc %Clear the Command Window
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
            %% Fill buffers to play audio (passage/topic)
            PsychPortAudio('FillBuffer', pahandle, buffer(bufferCnt));

            %% Play the audio (passage/topic) and send trigger to Oxysoft
            % Right before the sentence begins, send the trigger
            disp(['Playing Condition ', num2str(conditionOrder(k)), ' Passage ',num2str(bufferCnt),'...']);
            outlet.push_sample({['Cond', num2str(conditionOrder(k)), '-Passage',num2str(bufferCnt)]}); % Send the trigger to the outlet

            % Play the audio
            PsychPortAudio('Start', pahandle, [], 0, 1);
            WaitSecs(audioDuration(bufferCnt)); % Wait for the audio to finish playing before proceeding with rest of code
            %% Next passage
            % The next passage will be played after a 20 sec silent period.
            if bufferCnt == nfiles
                outlet.push_sample({'Condition End'});
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
disp('Experiment done.')