function remove_quotes(code, prepend)
    postpend = """```"""
    if startswith(code, prepend) && endswith(code, postpend)
        code = code[length(prepend) + 1:end-length(postpend)]
        code = strip(code)
    end
    code
end

function loop(device, device_read_buffer_length)
    # sentences = []
    # text_buffer = []
    PortAudioStream(device, maximum, maximum, samplerate=16000) do audio_stream # might need to adjust frames_per_buffer
        while !DONE
            @show "listening"
            # audio_buffer = read(stream, device_read_buffer_length)
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
                            code = remove_quotes(code, """```html""")
                            code = remove_quotes(code, """```""")
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
            yield()
        end
end

function stop()
    global DONE = true
    wait(loop_task)
end

DONE = false
loop_task = @async loop(device, 5s)

# check(loop_task)
