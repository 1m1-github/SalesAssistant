using Pkg
Pkg.add(["PortAudio", "LibSndFile", "SampledSignals", "FileIO", "Whisper"])
using LibSndFile, PortAudio, SampledSignals, FileIO, Whisper, HTTP, JSON, Suppressor

const WHISPER_FILENAME = "ggml-tiny.en.bin"
WHISPER_CONTEXT = Whisper.whisper_init_from_file(WHISPER_FILENAME)
WHISPER_PARAMS = Whisper.whisper_full_default_params(Whisper.LibWhisper.WHISPER_SAMPLING_GREEDY)
function transcribe(data)
    all(abs.(data) .< 1e-6) && return ""
    Whisper.whisper_full_parallel(WHISPER_CONTEXT, WHISPER_PARAMS, data, length(data), 1)
    n_segments = Whisper.whisper_full_n_segments(WHISPER_CONTEXT)
    result = ""
    for i in 0:n_segments-1
        txt = Whisper.whisper_full_get_segment_text(WHISPER_CONTEXT, i)
        result *= unsafe_string(txt)
    end
    result
end

const X_AI_API_KEY = ENV["X_AI_API_KEY"]
const WHAT_SYSTEM = """show me good info about what i ask using a HTML/JAVASCRIPT, which will be inserted into a `div`, always make it artsy, colorful, interesting"""
# const WHAT_SYSTEM = """
# You are a silent sales assistant.
# Provide suggestions for what to say next, relevant info, as HTML (a single `div` only please).
# We are selling automation, to small or mid sized business.
# Our company can automate anything.
# We want to find their pain point and suggest to automate it.
# And we want to close the sale during the call, to send a contract and ask for half upfront.
# Keep concise. I am on a sales phone call, meaning you should not write just long text, use HTML to allow me to see the most important information easily.
# """
const URL = "https://api.x.ai/v1/chat/completions"
const HEADERS = [
    "Authorization" => "Bearer $X_AI_API_KEY",
    "Content-Type" => "application/json"
]
function intelligence(what_user)
    messages = [Dict("role" => "system", "content" => WHAT_SYSTEM)]
    push!(messages, Dict("role" => "user", "content" => what_user))

    body = Dict(
        # "model" => "grok-4-1-fast-reasoning",
        "model" => "grok-code-fast-1",
        "stream" => false,
        "messages" => messages,
        "temperature" => 0.2,
    )
    body_string = JSON.json(body)

    @show "length(body_string)", length(body_string)

    response = HTTP.post(URL, HEADERS, body_string)
    result = JSON.parse(String(response.body))
    result["choices"][1]["message"]["content"]
end

function clean_whisper_text(x)
    rm_whisper_comments_pattern = r"\[.*?\]|\(.*?\)"
    x = replace(x, rm_whisper_comments_pattern => "")
    x = replace(x, "  " => " ")
    strip(x)
end

function remove_prepend(code, prepend)
    postpend = """```"""
    if startswith(code, prepend) && endswith(code, postpend)
        code = code[length(prepend) + 1:end-length(postpend)]
        code = strip(code)
    end
    code
end

function loop(device, device_read_buffer_length)
    sentences = []
    text_buffer = []
    stream = PortAudioStream(device, maximum, maximum, samplerate=16000) # might need to adjust frames_per_buffer
    try
        while !DONE
            @show "listening"
            audio_buffer = read(stream, device_read_buffer_length)
            @async begin
                text = @suppress transcribe(audio_buffer.data)
                @show "text", text
                text = clean_whisper_text(text)
                if endswith(text, "...")
                    text = replace(text, "..." => " ")
                end
                @show "text [] removed", text
                push!(text_buffer, text)
                for punctuation in ['.', ',', '!', ';', ')', '\n', '?']
                    if punctuation ∈ text
                        @show "punctuation", punctuation
                        timestamp = round(Int, time())
                        sentence = join(text_buffer, ' ')
                        empty!(text_buffer)
                        sentence = "<$timestamp>Potential Buyer: $sentence"
                        @show "sentence", sentence
                        push!(sentences, sentence)
                        # @async begin
                            @show "start intelligence"
                            prompt = join([
                                # "The current html is:",
                                # CURRENT_HTML,
                                "The conversation so far is:",
                                sentences...
                            ])
                            @show "prompt", prompt
                            code = intelligence(prompt)
                            @show "code", code
                            code = remove_prepend(code, """```html""")
                            code = remove_prepend(code, """```""")
                            global CURRENT_DIV
                            CURRENT_DIV = code
                            open("$timestamp.html", "w") do file
                                write(file, code)
                            end
                        # end
                        break
                    end
                end
            end
            sleep(0.1)
        end
    finally
        close(stream)
    end
end

const BASE_HTML = """
<!DOCTYPE html>
<html>
<head><title>Sales Assistant</title></head>
<body>
<div id='content'></div>
<script>
    const evtSource = new EventSource("/events");
    evtSource.onmessage = function(event) {
        console.log(event)
        document.getElementById("content").innerHTML = event.data;
    };
</script>
</body>
</html>
"""
CURRENT_DIV = ":)"
LAST_DIV = CURRENT_DIV

function serveClient(stream)
    @show "serveClient", stream.message
    if HTTP.method(stream.message) == "OPTIONS"
        HTTP.setstatus(stream, 200)
        HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, OPTIONS")
        HTTP.startwrite(stream)
        return
    end

    HTTP.setstatus(stream, 200)
    HTTP.setheader(stream, "Content-Type" => "text/html")
    HTTP.setheader(stream, "Cache-Control" => "no-cache")

    @show "serveClient 1"
    HTTP.startwrite(stream)
    @show "serveClient 2"
    write(stream, BASE_HTML)
    @show "serveClient 3"
    return
end

function send_sse_html(stream, html)
    @show "send_sse_html"
    lines = split(html, "\n")
    @show "send_sse_html", length(lines)
    for line in lines
        write(stream, "data: $(chomp(line))\n")
    end
    @show "send_sse_html 2"
    write(stream, "\n")
    @show "send_sse_html 3"
    flush(stream)
end

function events(stream)
    @show "events", stream.message
    if HTTP.method(stream.message) == "OPTIONS"
        HTTP.setstatus(stream, 200)
        HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, OPTIONS")
        HTTP.startwrite(stream)
        return
    end

    HTTP.setstatus(stream, 200)
    HTTP.setheader(stream, "Content-Type" => "text/event-stream")
    HTTP.setheader(stream, "Cache-Control" => "no-cache")
    HTTP.setheader(stream, "Connection" => "keep-alive")

    @show "events 1"
    HTTP.startwrite(stream)

    global LAST_DIV
    @show "events before", LAST_DIV, CURRENT_DIV
    send_sse_html(stream, CURRENT_DIV)
    LAST_DIV = CURRENT_DIV
    @show "events after", LAST_DIV, CURRENT_DIV

    try
        while !eof(stream)
            if CURRENT_DIV != LAST_DIV
                @show "CURRENT_DIV != LAST_DIV", LAST_DIV, CURRENT_DIV
                send_sse_html(stream, CURRENT_DIV)
                LAST_DIV = CURRENT_DIV
            end
            sleep(0.1)
        end
        @show "eof(stream)"
    catch e
        @info "Stream ended (disconnect?): $e"
    end
    return
end

const ROUTER = HTTP.Router()
HTTP.register!(ROUTER, "GET", "/", serveClient)
HTTP.register!(ROUTER, "/events", events)
server = HTTP.serve!(ROUTER, "127.0.0.1", 8080; stream=true)

DONE = false
devices = PortAudio.devices()
# device = only(filter(d -> d.name == "MacBook Air Microphone", devices))
device = only(filter(d -> d.name == "USB Audio" && d.input_bounds.max_channels == 1 && d.output_bounds.max_channels == 0, devices))
loop_task = @async loop(device, 5s)

# To check:
# istaskdone(loop_task)
# istaskfailed(loop_task)
# istaskstarted(loop_task)
# To stop:
# DONE = true;
# wait(loop_task);