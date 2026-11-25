# Copyright (c) 2020-2026, Bank of Canada
# All rights reserved.

# Package quality checks, https://github.com/JuliaTesting/Aqua.jl
using Aqua

@testset "Aqua" begin
    # LightXML is used only by deps/build.jl
    Aqua.test_all(FAME; stale_deps=(ignore=[:LightXML],))
end
