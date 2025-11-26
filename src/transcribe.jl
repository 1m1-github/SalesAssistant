@install Whisper, Suppressor

const SILENCE_THRESHOLD = 1e-6
const WHISPER_FILENAME = "ggml-large.en.bin"
const WHISPER_CONTEXT = Whisper.whisper_init_from_file(WHISPER_FILENAME)
const WHISPER_PARAMS = Whisper.whisper_full_default_params(Whisper.LibWhisper.WHISPER_SAMPLING_GREEDY)
function transcribe(data)
    @suppress begin
        result = ""
        all(abs.(data) .< SILENCE_THRESHOLD) && return result
        Whisper.whisper_full_parallel(WHISPER_CONTEXT, WHISPER_PARAMS, data, length(data), 1)
        n_segments = Whisper.whisper_full_n_segments(WHISPER_CONTEXT)
        for i in 0:n_segments-1
            txt = Whisper.whisper_full_get_segment_text(WHISPER_CONTEXT, i)
            result *= unsafe_string(txt)
        end
        result
    end
end

const RM_WHISPER_COMMENTS_PATTERN = r"\[.*?\]|\(.*?\)"
function clean_whisper_text(x)
    x = replace(x, RM_WHISPER_COMMENTS_PATTERN => "")
    x = replace(x, "  " => " ")
    strip(x)
end

# test
buffers = []
PortAudioStream(device, maximum, maximum, samplerate=16000) do stream
    buffer = read(stream)
    push!(buffers, buffer)
end

