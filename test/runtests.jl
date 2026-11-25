# Copyright (c) 2020-2026, Bank of Canada
# All rights reserved.

using Test
using FAME

include("aqua.jl")

if FAME.chli.lib === nothing
    @warn "The CHLI library was not found: the tests that need FAME (chli_tests.jl) are skipped."
else
    include("chli_tests.jl")
end

# these replace the library with a stand-in, so they come last
include("mock_tests.jl")
