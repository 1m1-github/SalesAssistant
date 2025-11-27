@install Whisper
@install SampledSignals
@install Suppressor

const SILENCE_THRESHOLD = 1e-6
# const WHISPER_FILENAME = "ggml-large-v3.bin"
const WHISPER_FILENAME = "ggml-base.en.bin"
# const WHISPER_FILENAME = "ggml-small.en.bin"
# const WHISPER_FILENAME = "ggml-tiny.en.bin"
const WHISPER_CONTEXT = Whisper.whisper_init_from_file(WHISPER_FILENAME)
const WHISPER_PARAMS = Whisper.whisper_full_default_params(Whisper.LibWhisper.WHISPER_SAMPLING_GREEDY)
function transcribe(data)
    @suppress begin
        result = ""
        all(abs.(data) .< SILENCE_THRESHOLD) && return result
        Whisper.whisper_full_parallel(WHISPER_CONTEXT, WHISPER_PARAMS, data, length(data), Threads.nthreads() - 1)
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
    if endswith(x, "...")
        x = replace(x, "..." => " ")
    end
    x = replace(x, "  " => " ")
    strip(x)
end

function sentence_end(text)
    for punctuation in ['.', ',', ';', '!', '?', '\n']
        index = findfirst(string(punctuation), text)
        !isnothing(index) && return index[1]
    end
    nothing
end

const SPEAKER = "imi"

transcribe_channel = Channel{SampleBuf}()
text_buffer = []
sentences = []
TRANSCRIBING = Ref(true)
transcribe_task = @async while TRANSCRIBING[]
    yield()
    audio_buffer = take!(transcribe_channel)
    @show "transcribe got audio_buffer" # DEBUG
    text = transcribe(audio_buffer.data)
    text = clean_whisper_text(text)
    @show "transcribe got text", text # DEBUG
    push!(text_buffer, text)
    full_buffer = join(text_buffer, ' ')
    sentence_end_ix = sentence_end(full_buffer)
    isnothing(sentence_end_ix) && continue
    timestamp = round(Int, time())
    pre_punctuation = full_buffer[1:sentence_end_ix[1]]
    sentence = "<$timestamp>$SPEAKER: $pre_punctuation"
    @show "transcribe got sentence", sentence # DEBUG
    push!(sentences, sentence)
    empty!(text_buffer)
    post_punctuation = full_buffer[sentence_end_ix[1]+1:end]
    if !isempty(post_punctuation)
        append!(text_buffer, split(post_punctuation, ' ', keepempty=false))
    end
    conversation = join(sentences, '\n')
    write("conversation", conversation) # DEBUG
    put!(intelligence_channel, conversation)
end

# check(transcribe_task)
