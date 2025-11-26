@install PortAudio
devices = PortAudio.devices()
device = only(filter(d -> d.name == "MacBook Air Microphone", devices))
device = only(filter(d -> d.name == "USB Audio" && d.input_bounds.max_channels == 1 && d.output_bounds.max_channels == 0, devices))

PortAudioStream(device, maximum, maximum, samplerate=16000) do stream # might need to adjust frames_per_buffer
    const AUDIO_BUFFER_LENGTH = 2s
    audio_buffer = read(stream, AUDIO_BUFFER_LENGTH)
end

# @install FileIO
# save("test.ogg", audio_buffer)
# load("test.ogg")
