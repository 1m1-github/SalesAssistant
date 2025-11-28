# DOM_ERRORS = String[]

function send_virtual_js(stdin_pipe, js_code)
    write(stdin_pipe, js_code * "\n")
    flush(stdin_pipe)
end

function start_virtual_dom()
    stdin_pipe = Pipe()
    pipe = pipeline(`node dom/dom-manager.js`, stdin=stdin_pipe)
    # stderr_pipe = Pipe()
    # pipe = pipeline(`node dom/dom-manager.js`, stdin=stdin_pipe, stderr=stderr_pipe)
    process = run(pipe, wait=false)

    # @async begin
    #     global DOM_ERRORS
    #     while !eof(stderr_pipe)
    #         err_line = readavailable(stderr_pipe)
    #         if !isempty(err_line)
    #             err_str = string(err_line)
    #             push!(DOM_ERRORS, err_str)
    #             while length(DOM_ERRORS) > 20
    #                 popfirst!(DOM_ERRORS)
    #             end
    #             # @show "DOM error: $err_str" # or log
    #         end
    #     end
    # end

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
