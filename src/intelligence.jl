@install HTTP
@install JSON3
@install BufferedStreams

const X_AI_API_KEY = ENV["X_AI_API_KEY"]
const INPUT_SYSTEM = """
    You are an assistant that shows relevant info on the browser during a call without speaking.
    You send back javascript code only. It allows you full granular control of the client browser.
    Since you are streaming, send the js in smaller chunks inside curly brackets {}, which will be executed on the client as soon as a } hits, making the user experience smoother, only adding little data, even creating an alternative effect to a simple pop up.
    You will also see the inner of the `body` of the DOM with large attributes truncated in the requests and the conversation and some context (company, product, etc.).
    Keep concise, impressive looking, like future world high levelt tech.
    Use tailwind assuming it loaded with a css file (theme), without inling styling only using classes and ids and chartjs as well if appropriate.
"""
const URL = "https://api.x.ai/v1/chat/completions"
const HEADERS = [
    "Authorization" => "Bearer $X_AI_API_KEY",
    "Content-Type" => "application/json"
]

function prepare_body(input_user)
    dom_file = "dom/dom.html"
    dom = isfile(dom_file) ? read(dom_file, String) : ""
    # global DOM_ERRORS
    # errors = join(DOM_ERRORS, '\n')
    # empty!(DOM_ERRORS)
    # input_user = "<body>" * dom * "</body>\n<errors>" * errors * "</errors>\n" * input_user
    input_user = "<body>" * dom * "</body>" * input_user
    messages = [Dict("role" => "system", "content" => INPUT_SYSTEM)]
    push!(messages, Dict("role" => "user", "content" => input_user))
    body = Dict(
        "model" => "grok-4-1-fast-reasoning",
        # "model" => "grok-code-fast-1",
        "stream" => true,
        "messages" => messages,
        "temperature" => 0.2,
        # "max_tokens" => 2^12,
    )
    JSON3.write(body)
end

function get_delta(data)
    GOOD_START = "data: "
    !startswith(data, GOOD_START) && return ""
    chunk = strip(data[length(GOOD_START):end])
    chunk == "[DONE]" && return ""
    json = JSON3.read(chunk)
    # @assert length(json["choices"]) == 1 # DEBUG
    get(json["choices"][1]["delta"], "content", "")
end

function send_command!(stream_deltas)
    js_command = join(stream_deltas.deltas)
    first_bracket_open_range = findfirst('{', js_command)
    isnothing(first_bracket_open_range) && return false
    first_bracket_open = first_bracket_open_range[1]
    last_bracket_close_range = findlast('}', js_command)
    isnothing(last_bracket_close_range) && return false
    last_bracket_close = last_bracket_close_range[1]
    js_command = js_command[first_bracket_open:last_bracket_close]
    @show "send_command!", js_command # DEBUG
    write("tmp/js_command-$(time()).js", js_command) # DEBUG
    send_virtual_js(js_command)
    send_js(js_command)
    stream_deltas.commands_sent +=1
    empty!(stream_deltas.deltas)
    true
end

function update!(stream_deltas, data)
    delta = get_delta(data)
    isempty(delta) && return false
    stream_deltas.brackets_opened += count(==('{'), delta)
    brackets_closed = count(==('}'), delta)
    stream_deltas.brackets_opened -= brackets_closed
    stream_deltas.brackets_opened = max(0, stream_deltas.brackets_opened)
    push!(stream_deltas.deltas, delta)
    stream_deltas.brackets_opened == 0 && 0 < brackets_closed
end
mutable struct StreamDeltas
    stream::Union{HTTP.Stream, Nothing}
    deltas::Vector{String}
    brackets_opened::Int
    commands_sent::Int
    start::Bool
    stop::Bool
end

CURRENT_STREAM_DELTAS = StreamDeltas(nothing, [], 0, 0, false, false)
function intelligence(input)
    HTTP.open("POST", URL;
        headers=HEADERS,
        decompressor=identity,
        reuse=false
    ) do stream
        try
            # @show "intelligence got stream"
            global CURRENT_STREAM_DELTAS
            if CURRENT_STREAM_DELTAS.start
                CURRENT_STREAM_DELTAS.stop = true
                if !isnothing(CURRENT_STREAM_DELTAS.stream)
                    try HTTP.closeread(CURRENT_STREAM_DELTAS.stream) catch e @show e end
                end
            end
            CURRENT_STREAM_DELTAS = StreamDeltas(stream, [], 0, 0, true, false)
            body = prepare_body(input)
            write("tmp/body-$(time()).txt", body) # DEBUG
            write(stream, body)
            HTTP.closewrite(stream)
            HTTP.startread(stream)
            buffered_stream = BufferedInputStream(stream)
            for data in eachline(buffered_stream)
                # @show "intel data", data # DEBUG
                if update!(CURRENT_STREAM_DELTAS, data)
                    send_command!(CURRENT_STREAM_DELTAS)
                end
            end
            CURRENT_STREAM_DELTAS.start = false
        catch e @show e end
    end
end

intelligence_channel = Channel{String}()

INTELLIGENCING = Ref(true)
intelligence_task = @async while INTELLIGENCING[]
    yield()
    text = take!(intelligence_channel)
    # @show "intelligence got text", text
    @async intelligence(text)
end

# check(intelligence_task)
