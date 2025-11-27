function stop()
    # global LOOPING = false
    LOOPING[] = false
    wait(loop_task)
end

LOOPING = Ref(true)
loop_task = @async while LOOPING[]
    yield()
    audio_buffer = take!(audio_channel)
    @show "loop got audio_buffer"
    put!(transcribe_channel, audio_buffer)
end

# check(loop_task)
# stop()
