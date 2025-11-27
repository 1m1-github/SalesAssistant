@install HTTP
@install Dates

JS = ""
send_js(js) = global JS = js
add_js_to_html(html, js) = replace(html, "</body>" => "<script>$js</script></body>")

const PING_EVENT = ":\n\n"
const PING_DISTANCE = 10.0

const EVENT_SOURCE_JS = read("src/base.js", String)
const BASE_HTML = add_js_to_html(read("src/base.html", String), EVENT_SOURCE_JS)

function send_sse_html(stream, html)
    lines = split(html, "\n")
    # @show "send_sse_html", length(lines)
    for line in lines
        write(stream, "data: $(chomp(line))\n")
    end
    write(stream, "\n")
    flush(stream)
end

function send_ping(stream)
    # @show "send_ping"
    write(stream, PING_EVENT)
    flush(stream)
end

function serve(stream)
    # @show "serve", HTTP.method(stream.message)
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
    HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")

    HTTP.startwrite(stream)
    write(stream, BASE_HTML)
    return
end

function events(stream)
    @show "events", HTTP.method(stream.message)
    if HTTP.method(stream.message) == "OPTIONS"
        HTTP.setstatus(stream, 200)
        HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, OPTIONS")
        HTTP.setheader(stream, "Access-Control-Allow-Headers" => "Content-Type")
        HTTP.startwrite(stream)
        return
    end

    HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
    HTTP.setheader(stream, "Content-Type" => "text/event-stream")
    HTTP.setheader(stream, "Cache-Control" => "no-cache")
    HTTP.setheader(stream, "Connection" => "keep-alive")

    send_ping(stream)
    last_ping = time()

    try
        while true
            yield()
            
            if PING_DISTANCE < time() - last_ping
                send_ping(stream)
                last_ping = time()
            end

            global JS
            isempty(JS) && continue
            send_sse_html(stream, JS)
            JS = ""
        end
        @show "eof(stream)"
    catch e
        @show "Stream ended (disconnect?): $e"
    end
    return
end

function serve_css(stream)
    if HTTP.method(stream.message) == "OPTIONS"
        HTTP.setstatus(stream, 200)
        HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, OPTIONS")
        HTTP.setheader(stream, "Access-Control-Allow-Headers" => "Content-Type")
        HTTP.startwrite(stream)
        return
    end

    HTTP.setstatus(stream, 200)
    HTTP.setheader(stream, "Content-Type" => "text/css")
    HTTP.setheader(stream, "Cache-Control" => "no-cache")
    HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")

    HTTP.startwrite(stream)
    open("css/futurism-theme.css") do f
        write(stream, read(f, String))
    end
    return
end

const ROUTER = HTTP.Router()
HTTP.register!(ROUTER, "GET", "/", serve)
HTTP.register!(ROUTER, "GET", "/futurism-theme.css", serve_css)
HTTP.register!(ROUTER, "/events", events)
http_task = @async HTTP.serve!(ROUTER, "127.0.0.1", 8080; stream=true)

# check(http_task)
