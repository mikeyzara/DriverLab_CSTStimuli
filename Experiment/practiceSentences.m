function practiceSentences(audioIdx,filepath_s,filepath_n,freq)

[practiceSentence_s, infreq_s] = psychwavread(filepath_s(audioIdx).name);
[practiceSentence_n, infreq_n] = psychwavread(filepath_n(audioIdx).name);

% Resampling if file sample freq not the same as audio device sample freq
if infreq_s ~= freq
    practiceSentence_s = resample(practiceSentence_s, freq, infreq_s); %Resample to 48kHz
end
% Resampling if file sample freq not the same as audio device sample freq
if infreq_n ~= freq
    practiceSentence_n = resample(practiceSentence_n, freq, infreq_n); %Resample to 48kHz
end

if length(practiceSentence_s) > length(practiceSentence_n) %If signal is longer than noise
    practiceSentence_s = practiceSentence_s(1:length(practiceSentence_n));
elseif length(practiceSentence_s) < length(practiceSentence_n) %If noise is longer than signal
    practiceSentence_n = practiceSentence_n(1:length(practiceSentence_s));
end

% Convert signal to stereo
practiceAudio = [practiceSentence_s';practiceSentence_n']; % Stereo signal means we have two rows in the matrix

% Playback
sound(practiceAudio,freq); %Play the audio file
WaitSecs(size(practiceAudio,2)/freq); %Wait for the audio to finish playing
end