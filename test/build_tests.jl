# Copyright (c) 2020-2026, Bank of Canada
# All rights reserved.

# FAME loads before it is built, and is precompiled again once it is built.
# Runs in separate Julia processes, with deps/FAMEMessages.jl moved aside.

using Test
using FAME

@testset "build" begin
    file = joinpath(pkgdir(FAME), "deps", "FAMEMessages.jl")
    # an installed package is read-only
    writable = isfile(file) && try
        touch(file)
        true
    catch
        false
    end
    if !writable
        @info "deps/FAMEMessages.jl is missing or read-only: build test skipped"
    else
        saved = read(file)
        load(code) = readchomp(pipeline(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $code`; stderr=devnull))
        show_state = "using FAME; print(FAME.HSUCC, \" \", FAME.HTRUNC, \" \", FAME.chli_help_file)"
        try
            rm(file)
            @test load(show_state) == "0 18 not found"
            write(file, """
                chli_help_file = "built"
                chli_status_description = Dict{Int32, String}(0 => "Success.")
                const HSUCC = Int32(0)
                const HNOOBJ = Int32(13)
                const HTRUNC = Int32(18)
                const HBOPT = Int32(67)
                """)
            @test load(show_state) == "0 18 built"
        finally
            write(file, saved)
        end
    end
end
