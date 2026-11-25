# Copyright (c) 2020-2026, Bank of Canada
# All rights reserved.

# Tests that do not need FAME, with a stand-in for the CHLI library.

using Test
using FAME
using TimeSeriesEcon

FAME.close_chli()
include("mock_chli.jl")
FAME.init_chli()

mock_roundtrip(name, value) = begin
    db = workdb()
    do_write(refame(name, value), db)
    unfame(do_read!(quick_info(db, uppercase(string(name))), db))
end

@testset "mock, basics" begin
    MockCHLI.reset()
    @test FAME.version() == v"11.5"
    w = Workspace(; a=1, b=TSeries(2020Q1, collect(1.0:10)), b32=TSeries(2020M1, Float32.(1:5)),
        bo=TSeries(2020Q1, [true, false]), s=MVTSeries(2020M1, (:q, :p), reshape(collect(1.0:48), 24, 2)),
        c=Workspace(; alpha=0.1, n=Workspace(; s="Hello World")), d=2021Q3, e=TSeries(2020Q1),
        sv=["qmazing", "qmazing", "p", ""], nl="{A,B}", st="p", wk=weekly("2020-03-04", 3))
    writefame(workdb(), w)
    r = readfame(workdb(); collect=["c" => ["n"], "s"])
    @test issetequal(keys(r), keys(w))
    for n in (:b, :b32, :bo, :e)
        @test rangeof(r[n]) == rangeof(w[n]) && r[n].values == w[n].values && eltype(r[n]) == eltype(w[n])
    end
    for n in (:d, :sv, :nl, :st, :wk)
        @test r[n] == w[n]
    end
    @test r.a === 1.0f0
    @test r.c.n.s == "Hello World"
    @test r.s.q.values == w.s.q.values
    @test allunique(o.name for o in listdb(workdb()))
end

@testset "mock, dates" begin
    # the date is a 64-bit integer
    p = FAME.Period{:quarterly_december}(Int32(2)^30, 1)
    @test FAME.FameIndex(p) == 4 * Int64(2)^30
end

@testset "mock, strings" begin
    MockCHLI.reset()
    # lengths are in bytes
    @test mock_roundtrip(:sa, "été") == "été"
    @test mock_roundtrip(:sb, "été à") == "été à"
    @test mock_roundtrip(:sc, ["a", "à", "bébé", ""]) == ["a", "à", "bébé", ""]
    @test mock_roundtrip(:sd, "") == ""
    @test mock_roundtrip(:se, repeat("abc", 200)) == repeat("abc", 200)
end

@testset "mock, names" begin
    MockCHLI.reset()
    @test isdefined(FAME, :HTRUNC)
    long = "L" * repeat("X", 150)
    for n in ("A", long, "Z")
        do_write(refame(Symbol(n), 1.0), workdb())
    end
    @test [o.name for o in listdb(workdb())] == ["A", long, "Z"]
    # too long: not listed, with a warning, and the others are listed
    do_write(refame(Symbol("M" * repeat("X", 2000)), 1.0), workdb())
    names = @test_logs (:warn, r"too long") [o.name for o in listdb(workdb())]
    @test names == ["A", long, "Z"]
end

@testset "mock, names as symbols" begin
    MockCHLI.reset()
    for n in (:a, :z)
        do_write(refame(n, 1.0), workdb())
    end
    @test readfame(workdb(), :a).a == 1.0
    @test readfame(workdb(), "a").a == 1.0
    @test length(readfame(workdb(), Symbol("?"))) == 2
end

@testset "mock, commands" begin
    MockCHLI.reset()
    MockCHLI.ERRTEXT[] = repeat("long message ", 40) * "end"
    err = try
        fame("bad command"; quiet=true)
    catch e
        e
    end
    @test err isa FAME.HLIError
    @test err.msg == MockCHLI.ERRTEXT[]
    # the output is restored after an error
    @test last(MockCHLI.COMMANDS) == "output terminal"
end

# leave no library behind for `atexit`
Core.eval(FAME, :(global chli = Chli{FameDatabase}(nothing)))
