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

@testset "mock, missing scalars" begin
    MockCHLI.reset()
    m = MockCHLI.MISSING
    @test refame(:x, NaN).data[] == m.NC64[]
    @test refame(:x, NaN32).data[] == m.NC32[]
    @test isnan(mock_roundtrip(:x, NaN))
    @test mock_roundtrip(:x, 1.5) == 1.5
end

@testset "mock, missing observations" begin
    MockCHLI.reset()
    m = MockCHLI.MISSING
    # an empty series is a single NA; a single missing observation is not empty
    for T in (Float64, Float32, Bool, MIT{Monthly})
        r = mock_roundtrip(:e, TSeries(T, 2020Q1))
        @test isempty(r) && eltype(r) == T && firstdate(r) == 2020Q1
    end
    for x in (NaN, NaN32)
        r = mock_roundtrip(:o, TSeries(2020Q1, [x]))
        @test length(r) == 1 && isnan(r[2020Q1]) && typeof(r[2020Q1]) == typeof(x)
    end
    r = mock_roundtrip(:o, TSeries(2020Q1, [typenan(MIT{Monthly})]))
    @test length(r) == 1 && istypenan(r[2020Q1])
    for (code, n) in (m.NA64[] => 0, m.NC64[] => 1, m.ND64[] => 1)
        fo = refame(:o, TSeries(2020Q1, [1.0]))
        fo.data[1] = code
        do_write(fo, workdb())
        @test length(readfame(workdb(), "o").o) == n
    end
    r = mock_roundtrip(:o, TSeries(2020Q1, [1.0, NaN, 3.0]))
    @test isequal(r.values, [1.0, NaN, 3.0])
end

@testset "mock, missing booleans" begin
    MockCHLI.reset()
    m = MockCHLI.MISSING
    # `Bool` has no missing value: warn
    fo = refame(:b, TSeries(2020Q1, [true, false, true]))
    fo.data[2] = m.NCB[]
    do_write(fo, workdb())
    r = @test_logs (:warn, r"b: 1 missing boolean"i) readfame(workdb(), "b")
    @test r.b.values == [true, true, true]
    fo = refame(:b, TSeries(2020Q1, [true]))
    fo.data[1] = m.NCB[]
    do_write(fo, workdb())
    r = @test_logs (:warn, r"b: 1 missing boolean"i) readfame(workdb(), "b")
    @test r.b.values == [true]
    @test (@test_logs mock_roundtrip(:b, TSeries(2020Q1, [true, false]))).values == [true, false]
end

struct InterruptingValue end
FAME.refame(::Symbol, ::InterruptingValue) = throw(InterruptException())
struct InterruptingDict end
Base.setindex!(::InterruptingDict, _, ::Symbol) = throw(InterruptException())

@testset "mock, skipped objects" begin
    MockCHLI.reset()
    db = workdb()
    # problem objects do not stop the others, one warning at the end
    @test_logs (:info, r"bad") (:warn, r"1 of 3 objects were not written: bad\.") match_mode = :all writefame(db, Workspace(; a=1.0, bad=1im, z=2.0))
    @test_logs (:info, r"c_bad") (:warn, r"1 of 2 objects were not written: c_bad\.") match_mode = :all writefame(db, Workspace(; c=Workspace(; bad=1im, ok=1.0)))
    do_write(refame(:q, TSeries(2020Q1, [1.0])), db)
    MockCHLI.DB["Q"].fr = 226    # secondly, not in TimeSeriesEcon
    r = @test_logs (:info, r"Q") (:warn, r"1 of 4 objects were not read: Q\.") match_mode = :all readfame(db)
    @test issetequal(keys(r), (:a, :c_ok, :z))
    delete!(MockCHLI.DB, "Q")
    @test length(@test_logs readfame(db)) == 3
    # long lists are shortened
    @test_logs (:warn, r"25 of 30 objects were not read: n1, .*n20, and 5 more\.") FAME._warn_skipped(["n$i" for i = 1:25], 30, "read")
    # Ctrl-C is not a problem object
    @test_throws InterruptException writefame(db, Workspace(; a=InterruptingValue()))
    @test_throws InterruptException FAME._readfame!(InterruptingDict(), :a, quick_info(db, "A"), db)
end

# leave no library behind for `atexit`
Core.eval(FAME, :(global chli = Chli{FameDatabase}(nothing)))
