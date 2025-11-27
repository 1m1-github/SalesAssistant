@install PortAudio
@install SampledSignals

const TOKEN_DURATION = 2s
const FRAMES_PER_SECOND = 16000
const FRAMES_PER_BUFFER = 2^8

devices = PortAudio.devices()
# device = only(filter(d -> d.name == "MacBook Air Microphone", devices))
device = only(filter(d -> d.name == "USB Audio" && d.input_bounds.max_channels == 1 && d.output_bounds.max_channels == 0, devices))
@show device # DEBUG

audio_channel = Channel{SampleBuf}()

RECORDING = Ref(true)
audio_task = @async PortAudioStream(device, maximum, maximum, samplerate = FRAMES_PER_SECOND, frames_per_buffer = FRAMES_PER_BUFFER) do stream
    while RECORDING[]
        yield()
        audio_buffer = read(stream, TOKEN_DURATION)
        @show "got audio_buffer" # DEBUG
        put!(audio_channel, audio_buffer)
    end
end

# check(audio_task)

# @install FileIO
# save("test.ogg", audio_buffer)
# load("test.ogg")
# stream=PortAudioStream(device, maximum, maximum, samplerate = FRAMES_PER_SECOND, frames_per_buffer = FRAMES_PER_BUFFER) ; audio_buffer = read(stream, TOKEN_DURATION)
