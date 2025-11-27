function stop_all()
    RECORDING[] = TRANSCRIBING[] = LOOPING[] = INTELLIGENCING[] = false
    wait(audio_task, loop_task, transcribe_task, intelligence_task, http_task)
    stop_virtual_dom(stdin_pipe, process)
end

LOOPING = Ref(true)
loop_task = @async while LOOPING[]
    yield()
    audio_buffer = take!(audio_channel)
    @show "loop got audio_buffer"
    put!(transcribe_channel, audio_buffer)
end

atexit(stop_all)

# check(loop_task)
