@install HTTP
@install JSON3

const X_AI_API_KEY = ENV["X_AI_API_KEY"]
# const WHAT_SYSTEM = """show me good info about what i ask using a HTML/JAVASCRIPT, which will be inserted into a `div`, always make it artsy, colorful, interesting"""
const WHAT_SYSTEM = """
    You are a sales assistant that shows relevant info on the screen during a call without speaking.
    You send back Julia code only. It will run on the server.
    Use `send_js(js)` to have js executed in the client
    Since you are streaming, send the js in smaller chunks inside curly brackets {}, which will be executed on the client as soon as a } hits.
    You will also see most of the DOM in the requests which is a conversation and some context (company, etc.).
    And we want to close the sale during the call, to send a contract and ask for half upfront.
    Keep concise. I am on a sales phone call, meaning you should not write just long text, use HTML to allow me to see the most important information easily.
    tailwind is available in the client, use it to make everything look nice.
"""
const URL = "https://api.x.ai/v1/chat/completions"
const HEADERS = [
    "Authorization" => "Bearer $X_AI_API_KEY",
    "Content-Type" => "application/json"
]
function intelligence(what_user)
    messages = [Dict("role" => "system", "content" => WHAT_SYSTEM)]
    push!(messages, Dict("role" => "user", "content" => what_user))

    body = Dict(
        "model" => "grok-4-1-fast-reasoning",
        # "model" => "grok-code-fast-1",
        "stream" => true,
        "messages" => messages,
        "temperature" => 0.2,
    )
    body_string = JSON3.json(body)

    # @show "length(body_string)", length(body_string)

    # response = HTTP.post(URL, HEADERS, body_string)
    # result = JSON3.parse(String(response.body))
    # result["choices"][1]["message"]["content"]

    HTTP.open("POST", URL;
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
end


## streaming

lines = []


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
