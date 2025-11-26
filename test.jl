## pkg

using Pkg
Pkg.add(["PortAudio", "LibSndFile", "SampledSignals", "FileIO", "Whisper"])
using LibSndFile, PortAudio, SampledSignals, FileIO, Whisper, HTTP, JSON
devices = PortAudio.devices()

## works for phone

stream = PortAudioStream(devices[2], 1, 0)
buf = read(stream, 5s)
close(stream)
save("test.ogg", buf)

## use mic for testing

stream = PortAudioStream(devices[4], 1, 0, samplerate=16000, eltype=Float32)
buf = read(stream, 5s)
close(stream)
save("test.ogg", buf)

## transcribe

# s = load("test.ogg")
# data = s.data
# data = buf.data

function transcribe(data)
    filename = "/Users/1m1/.julia/scratchspaces/124859b0-ceae-595e-8997-d05f6a7a8dfe/datadeps/whisper-ggml-tiny.en/ggml-tiny.en.bin"
    ctx = Whisper.whisper_init_from_file(filename)
    wparams = Whisper.whisper_full_default_params(Whisper.LibWhisper.WHISPER_SAMPLING_GREEDY)
    Whisper.whisper_full_parallel(ctx, wparams, data, length(data), 1)
    n_segments = Whisper.whisper_full_n_segments(ctx)
    result = ""
    for i in 0:n_segments-1
        txt = Whisper.whisper_full_get_segment_text(ctx, i)
        result *= unsafe_string(txt)
    end
    Whisper.whisper_free(ctx)
    result
end

## streaming

lines = []
HTTP.open("POST", url;
    headers=headers,
    # readtimeout=1000,
    # connect_timeout=30,
    verbose=true,
    decompressor=identity
) do grok_stream
    write(grok_stream, body_string)
    HTTP.closewrite(grok_stream)
    HTTP.startread(grok_stream)
    try
    for line in eachline(grok_stream)
        # @show "line", line
        push!(lines, line)
    end
    catch e
        @show "e", e
    end
end

@show lines
deltas = []
for line in lines
    !startswith(line, "data") && continue
    line == "data: [DONE]" && break
    @show line
    start_json = findfirst('{', line)
    response_json = JSON.parse(line[start_json:end])
    response_json["choices"]
    delta = response_json["choices"][1]["delta"]
    push!(deltas, delta)
end
filter(!isempty, deltas)

## grok

function intelligence(what_user)
    X_AI_API_KEY = ENV["X_AI_API_KEY"] = ""
    WHAT_SYSTEM = """
    You are a silent sales assistant.
    Provide suggestions for what to say next, relevant info, as HTML (can include javascript).
    We are selling automation, to small or mid sized business.
    Our company can automate anything.
    We want to find their pain point and suggest to automate it.
    And we want to close the sale during the call, to send a contract and ask for half upfront.
    Keep concise.
    """
    url = "https://api.x.ai/v1/chat/completions"
    headers = [
        "Authorization" => "Bearer $X_AI_API_KEY",
        "Content-Type" => "application/json"
    ]

    messages = [Dict("role" => "system", "content" => WHAT_SYSTEM)]
    push!(messages, Dict("role" => "user", "content" => what_user))
    
    body = Dict(
        "model" => "grok-4-1-fast-reasoning",
        "stream" => false,
        "messages" => messages,
        "temperature" => 0.2,
    )
    body_string = JSON.json(body)

    response = HTTP.post(url, headers, body_string)
    result = JSON.parse(String(response.body))
    result["choices"][1]["message"]["content"]
end

## loop

i=1
DONE = false
sentences = []
text_buffer = []
stream = PortAudioStream(devices[3], 1, 0, samplerate=16000, eltype=Float32)
while !DONE
    audio_buffer = read(stream, 2s)
    text = transcribe(audio_buffer.data)
    @show "text", text
    rm_whisper_comments_pattern = r"\[.*?\]|\(.*?\)"
    text = replace(text, rm_whisper_comments_pattern => "")
    text = strip(text)
    text = replace(text, "  " => " ")
    @show "text [] removed", text
    push!(text_buffer, text)
    for punctuation in ['.', ',', '!', ';', ')', '\n']
        if punctuation ∈ text
            timestamp = round(Int,time())
            sentence = join(text_buffer)
            sentence = "<$timestamp>Potential Buyer:"
            @show "full_text", full_text
            @async answer = intelligence(full_text)
            @show answer
            write("$timestamp.html", answer)
        end
    end
    @show i
    i += 1
    i == 5 && ( global DONE; DONE = true)
end
close(stream)
