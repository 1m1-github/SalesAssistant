function send_virtual_js(stdin_pipe, js_code)
    old_dom = read("dom/dom.html", String)
    write(stdin_pipe, js_code * "\n")
    flush(stdin_pipe)
    sleep(0.1) # todo fix
    new_dom = read("dom/dom.html", String)
    @show old_dom != new_dom # DEBUG
    old_dom != new_dom
end

function start_virtual_dom()
    stdin_pipe = Pipe()
    pipe = pipeline(`node dom/dom-manager.js`, stdin = stdin_pipe)
    process = run(pipe, wait=false)
    stdin_pipe, process
end

function stop_virtual_dom(stdin_pipe, process)
    send_virtual_js(stdin_pipe, "exit")
    kill(process)
end

stdin_pipe, process = start_virtual_dom()
send_virtual_js(js_code) = send_virtual_js(stdin_pipe, js_code)

# example: js_code="document.body.innerHTML += '<p>:)</p>'"
# stop_virtual_dom(stdin_pipe, process)
