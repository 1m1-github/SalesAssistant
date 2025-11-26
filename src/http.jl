@install HTTP
@install Dates

JS = ""
send_js(js) = global JS = js

const PING_EVENT = ":\n\n"
const PING_DISTANCE = 10.0

const BASE_HTML = """
<!DOCTYPE html>
<html>
<head><title>Sales Assistant</title></head>
<script src="https://cdn.tailwindcss.com"></script>
<body>
<div id='output'>aos></div>
<script>
    const eventSource = new EventSource('/events')
    eventSource.onmessage = function(event) {
        eval(event.data)
    }
    eventSource.onerror = function(event) {
        console.error('SSE error event:', event)
    }
</script>
</body>
</html>
"""

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
    HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")

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

function send_ping(stream)
    @show "send_ping"
    write(stream, PING_EVENT)
    flush(stream)
end

function events(stream)
    @show "events", HTTP.method(stream.message)
    if HTTP.method(stream.message) == "OPTIONS"
        HTTP.setstatus(stream, 200)
        HTTP.setheader(stream, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(stream, "Access-Control-Allow-Methods" => "GET, OPTIONS")
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

const ROUTER = HTTP.Router()
HTTP.register!(ROUTER, "GET", "/", serveClient)
HTTP.register!(ROUTER, "/events", events)
http_task = @async HTTP.serve!(ROUTER, "127.0.0.1", 8080; stream=true)

# check(http_task)
