import Pkg

macro install(pkgs...)
    new_pkgs = filter(pkg -> !isdefined(Main, pkg), pkgs)
    isempty(new_pkgs) && return
    Pkg.add.(string.(new_pkgs))
    esc(quote
        using $(new_pkgs...)
    end)
end

function check(task)
    map(f -> f(task), [istaskfailed, istaskstarted, istaskdone])
end
