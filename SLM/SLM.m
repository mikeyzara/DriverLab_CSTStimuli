close all
clear all

%% Need these folders for the audio files
addpath(genpath('Signal - Chan1'))
addpath(genpath('Noise - Chan2'))

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

while(1)
    %% Ask the user to select the file to play
    % The list of files for signal
    sigList = dir('Signal - Chan1');
    sigList = sigList(contains({sigList.name},'.wav'));

    % Select the signal
    [sigIdx,tfsig] = listdlg('PromptString',{'Select a SIGNAL file.',...
        'Only one file can be selected at a time.',''},...
        'SelectionMode','single','ListString',{sigList.name});

    % The list of files for noise
    noiseList = dir('Noise - Chan2');
    noiseList = noiseList(contains({noiseList.name},'.wav'));

    % Select the noise
    [noiseIdx,tfnoise] = listdlg('PromptString',{'Select a NOISE file.',...
        'Only one file can be selected at a time.',''},...
        'SelectionMode','single','ListString',{noiseList.name});

    %Make sure selection for noise and signal have been made
    if (tfsig == 1 && tfnoise == 1)

        % Prepare the audio files and store them to create a "playlist"
        sigPath = fullfile(sigList(sigIdx).folder,sigList(sigIdx).name);
        noisePath = fullfile(noiseList(noiseIdx).folder,noiseList(noiseIdx).name);

        buffer = [];% This will grow in size according to the number of buffers that are created

        % Read the audio files into MATLAB
        [signalData, infreq1] = psychwavread(sigPath);
        [noiseData, infreq2] = psychwavread(noisePath);

        % Check to see if freq of audio file and freq of playback the same
        if infreq1 ~= freq % If they're not, do some resampling
            signalData = resample(signalData, freq, infreq1); %Resample to 48kHz
        end
        if infreq2 ~= freq % If they're not, do some resampling
            noiseData = resample(noiseData, freq, infreq2); %Resample to 48kHz
        end

        % Make both signals the same length
        if length(signalData) > length(noiseData) %If signal is longer than noise
            signalData = signalData(1:length(noiseData));
        elseif length(signalData) < length(noiseData) %If noise is longer than signal
            noiseData = noiseData(1:length(signalData));
        end

        % Ask if user wants to test noise alone or signal+noise
        choice = questdlg('Which SLM do you want to do?','Sound Level Measurement','Babble','Signal + Babble','');
        if strcmp(choice,'Babble') == 1 % Babble only
            audiodata = [noiseData';noiseData'];
        elseif strcmp(choice,'Signal + Babble') == 1 % Signal+Noise
            audiodata = [signalData'; noiseData'];
        else
            break
        end
        audioDuration = length(audiodata)/freq; %Length of audio duration

        %Create a buffer and store the audio clip
        buffer = PsychPortAudio('CreateBuffer', [], audiodata);

        % Let's start loading the files into a buffer and playing the audio
        % file
        % But first, define some variables to be used by PsychPortAudio
        repetitions = []; %Default is 1
        when = []; %Default to 0 (start immediately)
        waitForStart = 1; %If ‘waitForStart’ is set to non-zero value, ie if PTB should
        % wait for sound onset, then the optional return argument ‘startTime’ will contain
        % an estimate of when the first audio sample hit the speakers, i.e., the real
        % start time.

        bufferCnt = 1;
        while(1) % Repeat the same test until user decides to move on
            s = PsychPortAudio('GetStatus', pahandle);
            if s.Active == 0
                % Fill buffers to play audio
                PsychPortAudio('FillBuffer', pahandle, buffer(bufferCnt));

                % Play the audio
                PsychPortAudio('Start', pahandle, [], 0, 1);
                WaitSecs(audioDuration(bufferCnt)); % Wait for the audio to finish playing before proceeding with rest of code
            end

            answer = questdlg('Do you want to repeat the same test?','Repeat','Yes','No','No');
            if strcmp(answer,'No') == 1 %Move on and select a different set of files
                break
            end
        end
        quit = questdlg('Do you want to quit?','Quit','Yes','No','Yes');
        if strcmp(quit,'Yes') == 1 %Ends the program
            break
        end
    else
        quit = questdlg('Do you want to quit?','Quit','Yes','No','Yes');
        if strcmp(quit,'Yes') == 1 %Ends the program
            break
        end
    end
end
% Close the audio device:
PsychPortAudio('Close', pahandle);