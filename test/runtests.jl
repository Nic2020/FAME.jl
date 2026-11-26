# Copyright (c) 2020-2026, Bank of Canada
# All rights reserved.

using Test
using FAME

# one test set around everything, so a failure does not skip what follows
@testset "FAME.jl" begin
    include("aqua.jl")
    include("build_tests.jl")

    if FAME.chli.lib === nothing
        @warn "The CHLI library was not found: the tests that need FAME (chli_tests.jl) are skipped."
    else
        include("chli_tests.jl")
    end

    # these replace the library with a stand-in, so they come last
    include("mock_tests.jl")
end
