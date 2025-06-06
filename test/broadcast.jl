# This file is a part of Julia. License is MIT: https://julialang.org/license

using Test, Random

module TestBroadcastInternals

using Base.Broadcast: check_broadcast_axes, check_broadcast_shape, newindex, _bcs
using Base: OneTo
using Test, Random

@test @inferred(_bcs((3,5), (3,5))) == (3,5)
@test @inferred(_bcs((3,1), (3,5))) == (3,5)
@test @inferred(_bcs((3,),  (3,5))) == (3,5)
@test @inferred(_bcs((3,5), (3,)))  == (3,5)
@test_throws DimensionMismatch _bcs((3,5), (4,5))
@test_throws DimensionMismatch _bcs((3,5), (3,4))
@test @inferred(_bcs((-1:1, 2:5), (-1:1, 2:5))) == (-1:1, 2:5)
@test @inferred(_bcs((-1:1, 2:5), (1, 2:5)))    == (-1:1, 2:5)
@test @inferred(_bcs((-1:1, 1),   (1, 2:5)))    == (-1:1, 2:5)
@test @inferred(_bcs((-1:1,),     (-1:1, 2:5))) == (-1:1, 2:5)
@test_throws DimensionMismatch _bcs((-1:1, 2:6), (-1:1, 2:5))
@test_throws DimensionMismatch _bcs((-1:1, 2:5), (2, 2:5))

@test @inferred(Broadcast.combine_axes(zeros(3,4), zeros(3,4))) == (OneTo(3),OneTo(4))
@test @inferred(Broadcast.combine_axes(zeros(3,4), zeros(3)))   == (OneTo(3),OneTo(4))
@test @inferred(Broadcast.combine_axes(zeros(3),   zeros(3,4))) == (OneTo(3),OneTo(4))
@test @inferred(Broadcast.combine_axes(zeros(3), zeros(1,4), zeros(1))) == (OneTo(3),OneTo(4))

check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,5))
check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,1))
check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3))
check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,5), zeros(3))
check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,5), 1)
check_broadcast_axes((OneTo(3),OneTo(5)), 5, 2)
@test_throws DimensionMismatch check_broadcast_axes((OneTo(3),OneTo(5)), zeros(2,5))
@test_throws DimensionMismatch check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,4))
@test_throws DimensionMismatch check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,4,2))
@test_throws DimensionMismatch check_broadcast_axes((OneTo(3),OneTo(5)), zeros(3,5), zeros(2))
check_broadcast_axes((-1:1, 6:9), 1)

check_broadcast_shape((-1:1, 6:9), (-1:1, 6:9))
check_broadcast_shape((-1:1, 6:9), (-1:1, 1))
check_broadcast_shape((-1:1, 6:9), (1, 6:9))
@test_throws DimensionMismatch check_broadcast_shape((-1:1, 6:9), (-1, 6:9))
@test_throws DimensionMismatch check_broadcast_shape((-1:1, 6:9), (-1:1, 6))

ci(x) = CartesianIndex(x)
@test @inferred(newindex(ci((2,2)), (true, true), (-1,-1)))   == ci((2,2))
@test @inferred(newindex(ci((2,2)), (true, false), (-1,-1)))  == ci((2,-1))
@test @inferred(newindex(ci((2,2)), (false, true), (-1,-1)))  == ci((-1,2))
@test @inferred(newindex(ci((2,2)), (false, false), (-1,-1))) == ci((-1,-1))
@test @inferred(newindex(ci((2,2)), (true,), (-1,-1))) == 2
@test @inferred(newindex(ci((2,2)), (true,), (-1,)))   == 2
@test @inferred(newindex(ci((2,2)), (false,), (-1,)))  == -1
@test @inferred(newindex(ci((2,2)), (), ())) == ci(())

end

function as_sub(x::AbstractVector)
    y = similar(x, eltype(x), tuple(([size(x)...]*2)...))
    y = view(y, 2:2:length(y))
    y[:] = x[:]
    y
end
function as_sub(x::AbstractMatrix)
    y = similar(x, eltype(x), tuple(([size(x)...]*2)...))
    y = view(y, 2:2:size(y,1), 2:2:size(y,2))
    for j=1:size(x,2)
        for i=1:size(x,1)
            y[i,j] = x[i,j]
        end
    end
    y
end
function as_sub(x::AbstractArray{T,3}) where T
    y = similar(x, eltype(x), tuple(([size(x)...]*2)...))
    y = view(y, 2:2:size(y,1), 2:2:size(y,2), 2:2:size(y,3))
    for k=1:size(x,3)
        for j=1:size(x,2)
            for i=1:size(x,1)
                y[i,j,k] = x[i,j,k]
            end
        end
    end
    y
end

bittest(f::Function, a...) = (@test f.(a...) == BitArray(broadcast(f, a...)))
n1 = 21
n2 = 32
n3 = 17
rb = 1:5

for arr in (identity, as_sub)
    @test broadcast(+, arr([1 0; 0 1]), arr([1, 4])) == [2 1; 4 5]
    @test broadcast(+, arr([1 0; 0 1]), arr([1  4])) == [2 4; 1 5]
    @test broadcast(+, arr([1  0]), arr([1, 4])) == [2 1; 5 4]
    @test broadcast(+, arr([1, 0]), arr([1  4])) == [2 5; 1 4]
    @test broadcast(+, arr([1, 0]), arr([1, 4])) == [2, 4]
    @test broadcast(+, arr([1, 0]), 2) == [3, 2]

    @test @inferred(broadcast(+, arr([1 0; 0 1]), arr([1, 4]))) == arr([2 1; 4 5])
    @test arr([1 0; 0 1]) .+ arr([1  4]) == arr([2 4; 1 5])
    @test arr([1  0]) .+ arr([1, 4]) == arr([2 1; 5 4])
    @test arr([1, 0]) .+ arr([1  4]) == arr([2 5; 1 4])
    @test arr([1, 0]) .+ arr([1, 4]) == arr([2, 4])
    @test arr([1]) .+ arr([]) == arr([])

    A = arr([1 0; 0 1]); @test broadcast!(+, A, A, arr([1, 4])) == arr([2 1; 4 5])
    A = arr([1 0; 0 1]); @test broadcast!(+, A, A, arr([1  4])) == arr([2 4; 1 5])
    A = arr([1  0]); @test_throws DimensionMismatch broadcast!(+, A, A, arr([1, 4]))
    A = arr([1  0]); @test broadcast!(+, A, A, arr([1  4])) == arr([2 4])
    A = arr([1  0]); @test broadcast!(+, A, A, 2) == arr([3 2])

    @test arr([ 1    2])   .* arr([3,   4])   == [ 3 6; 4 8]
    @test arr([24.0 12.0]) ./ arr([2.0, 3.0]) == [12 6; 8 4]
    @test arr([1 2]) ./ arr([3, 4]) == [1/3 2/3; 1/4 2/4]
    @test arr([1 2]) .\ arr([3, 4]) == [3 1.5; 4 2]
    @test arr([3 4]) .^ arr([1, 2]) == [3 4; 9 16]
    @test arr(BitArray([true false])) .* arr(BitArray([true, true])) == [true false; true false]
    @test arr(BitArray([true false])) .^ arr(BitArray([false, true])) == [true true; true false]
    @test arr(BitArray([true false])) .^ arr([0, 3]) == [true true; true false]

    M = arr([11 12; 21 22])
    @test getindex.((M,), [2 1; 1 2], arr([1, 2])) == [21 11; 12 22]
    @test_throws BoundsError getindex.((M,), [2 1; 1 2], arr([1, -1]))
    @test_throws BoundsError getindex.((M,), [2 1; 1 2], arr([1, 2]), [2])
    @test getindex.((M,), [2 1; 1 2],arr([2, 1]), [1]) == [22 12; 11 21]

    A = arr(zeros(2,2))
    setindex!.((A,), arr([21 11; 12 22]), [2 1; 1 2], arr([1, 2]))
    @test A == M
    setindex!.((A,), 5, [1,2], [2 2])
    @test A == [11 5; 21 5]
    setindex!.((A,), 7, [1,2], [1 2])
    @test A == fill(7, 2, 2)
    A = arr(zeros(3,3))
    setindex!.((A,), 10:12, 1:3, 1:3)
    @test A == [10 0 0; 0 11 0; 0 0 12]
    @test_throws BoundsError setindex!.((A,), 7, [1,-1], [1 2])

    for f in ((==), (<) , (!=), (<=))
        bittest(f, arr([1 0; 0 1]), arr([1, 4]))
        bittest(f, arr([1 0; 0 1]), arr([1  4]))
        bittest(f, arr([0, 1]), arr([1  4]))
        bittest(f, arr([0  1]), arr([1, 4]))
        bittest(f, arr([1, 0]), arr([1, 4]))
        bittest(f, arr(rand(rb, n1, n2, n3)), arr(rand(rb, n1, n2, n3)))
        bittest(f, arr(rand(rb,  1, n2, n3)), arr(rand(rb, n1,  1, n3)))
        bittest(f, arr(rand(rb,  1, n2,  1)), arr(rand(rb, n1,  1, n3)))
        bittest(f, arr(bitrand(n1, n2, n3)), arr(bitrand(n1, n2, n3)))
    end
end

let r1 = 1:1,
    r2 = 1:5,
    ratio = [1,1/2,1/3,1/4,1/5],
    m = [1:2;]'
    @test r1.*r2 == [1:5;]
    @test r1./r2 == ratio
    @test m.*r2 == [1:5 2:2:10]
    @test m./r2 ≈ [ratio 2ratio]
    @test m./[r2;] ≈ [ratio 2ratio]
end

@test @inferred(broadcast(+,[0,1.2],reshape([0,-2],1,1,2))) == reshape([0 -2; 1.2 -0.8],2,1,2)
rt = Base.return_types(broadcast, Tuple{typeof(+), Array{Float64, 3}, Array{Int, 1}})
@test length(rt) == 1 && rt[1] == Array{Float64, 3}
rt = Base.return_types(broadcast!, Tuple{Function, Array{Float64, 3}, Array{Float64, 3}, Array{Int, 1}})
@test length(rt) == 1 && rt[1] == Array{Float64, 3}

# f.(args...) syntax (#15032)
let x = [1, 3.2, 4.7],
    y = [3.5, pi, 1e-4],
    α = 0.2342
    @test sin.(x) == broadcast(sin, x)
    @test sin.(α) == broadcast(sin, α)
    @test sin.(3.2) == broadcast(sin, 3.2) == sin(3.2)
    @test factorial.(3) == broadcast(factorial, 3)
    @test atan.(x, y) == broadcast(atan, x, y)
    @test atan.(x, y') == broadcast(atan, x, y')
    @test atan.(x, α) == broadcast(atan, x, α)
    @test atan.(α, y') == broadcast(atan, α, y')
end

# issue 14725
let a = Number[2, 2.0, 4//2, 2+0im] / 2
    @test eltype(a) == Number
end
let a = Real[2, 2.0, 4//2] / 2
    @test eltype(a) == Real
end
let a = Real[2, 2.0, 4//2] / 2.0
    @test eltype(a) == Float64
end

# issue 16164
let a = broadcast(Float32, [3, 4, 5])
    @test eltype(a) == Float32
end

# broadcasting scalars:
@test sin.(1) === broadcast(sin, 1) === sin(1)
@test (()->1234).() === broadcast(()->1234) === 1234

# issue #4883
@test isa(broadcast(tuple, [1 2 3], ["a", "b", "c"]), Matrix{Tuple{Int,String}})
@test isa(broadcast((x,y)->(x==1 ? 1.0 : x, y), [1 2 3], ["a", "b", "c"]), Matrix{Tuple{Real,String}})
let a = length.(["foo", "bar"])
    @test isa(a, Vector{Int})
    @test a == [3, 3]
end
let a = sin.([1, 2])
    @test isa(a, Vector{Float64})
    @test a ≈ [0.8414709848078965, 0.9092974268256817]
end

# PR #17300: loop fusion
@test (x->x+1).((x->x+2).((x->x+3).(1:10))) == 7:16
let A = [sqrt(i)+j for i = 1:3, j=1:4]
    @test atan.(log.(A), sum(A, dims=1)) == broadcast(atan, broadcast(log, A), sum(A, dims=1))
end
let x = sin.(1:10)
    @test atan.((x->x+1).(x), (x->x+2).(x)) == broadcast(atan, x.+1, x.+2)
    @test sin.(atan.([x.+1,x.+2]...)) == sin.(atan.(x.+1 ,x.+2)) == @. sin(atan(x+1,x+2))
    @test sin.(atan.(x, 3.7)) == broadcast(x -> sin(atan(x,3.7)), x)
    @test atan.(x, 3.7) == broadcast(x -> atan(x,3.7), x) == broadcast(atan, x, 3.7)
end
# Use side effects to check for loop fusion.
let g = Int[]
    f17300(x) = begin; push!(g, x); x+2; end
    f17300.(f17300.(f17300.(1:3)))
    @test g == [1,3,5, 2,4,6, 3,5,7]
    empty!(g)
    @. f17300(f17300(f17300(1:3)))
    @test g == [1,3,5, 2,4,6, 3,5,7]
end
# fusion with splatted args:
let x = sin.(1:10), a = [x]
    @test cos.(x) == cos.(a...)
    @test atan.(x,x) == atan.(a..., a...) == atan.([x, x]...)
    @test atan.(x, cos.(x)) == atan.(a..., cos.(x)) == broadcast(atan, x, cos.(a...)) == broadcast(atan, a..., cos.(a...))
    @test ((args...)->cos(args[1])).(x) == cos.(x) == ((y,args...)->cos(y)).(x)
end
@test atan.(3, 4) == atan(3, 4) == (() -> atan(3, 4)).()
# fusion with keyword args:
let x = [1:4;]
    f17300kw(x; y=0) = x + y
    @test f17300kw.(x) == x
    @test f17300kw.(x, y=1) == f17300kw.(x; y=1) == f17300kw.(x; [(:y,1)]...) == x .+ 1 == [2, 3, 4, 5]
    @test f17300kw.(sin.(x), y=1) == f17300kw.(sin.(x); y=1) == sin.(x) .+ 1
    @test sin.(f17300kw.(x, y=1)) == sin.(f17300kw.(x; y=1)) == sin.(x .+ 1)
end

# issue #23236
let X = [[true,false],[false,true]]
    @test [.!x for x in X] == [[false,true],[true,false]]
end

# splice escaping of @.
let x = [4, -9, 1, -16]
    @test [2, 3, 4, 5] == @.(1 + sqrt($sort(abs(x))))
end

# interaction of @. with let
@test [1,4,9] == @. let x = [1,2,3]; x^2; end

# interaction of @. with for loops
let x = [1,2,3], y = x
    @. for i = 1:3
        y = y^2 # should convert to y .= y.^2
    end
    @test x == [1,256,6561]
end

# interaction of @. with function definitions
let x = [1,2,3]
    @. f(x) = x^2
    @test f(x) == [1,4,9]
end

# Issue #23622: @. with chained comparisons
let x = [1,2,3]
    @test (1 .< x .< 3) == @.(1 < x < 3) == (@. 1 .< x .< 3) == [false, true, false]
    @test (x .=== 1:3 .=== [1,2,3]) == @.(x === 1:3 === [1,2,3]) == [true, true, true]
end

# PR #17510: Fused in-place assignment
let x = [1:4;], y = x
    y .= 2:5
    @test y === x == [2:5;]
    y .= factorial.(x)
    @test y === x == [2,6,24,120]
    y .= 7
    @test y === x == [7,7,7,7]
    y .= factorial.(3)
    @test y === x == [6,6,6,6]
    f17510() = 9
    y .= f17510.()
    @test y === x == [9,9,9,9]
    y .-= 1
    @test y === x == [8,8,8,8]
    @. y -= 1:4          # @. should convert to .-=
    @test y === x == [7,6,5,4]
    x[1:2] .= 1
    @test y === x == [1,1,5,4]
    @. x[1:2] .+= [2,3]  # use .+= to make sure @. works with dotted assignment
    @test y === x == [3,4,5,4]
    @. x[:] .= 0         # use .= to make sure @. works with dotted assignment
    @test y === x == [0,0,0,0]
    @. x[2:end] = 1:3    # @. should convert to .=
    @test y === x == [0,1,2,3]
end
let a = [[4, 5], [6, 7]], b = reshape(a, 1, 2)
    a[1] .= 3
    @test a == [[3, 3], [6, 7]]
    a[CartesianIndex(1)] .= 4
    @test a == [[4, 4], [6, 7]]
    b[1, CartesianIndex(1)] .= 5
    @test a == [[5, 5], [6, 7]]
end
let d = Dict(:foo => [1,3,7], (3,4) => [5,9])
    d[:foo] .+= 2
    @test d[:foo] == [3,5,9]
    d[3,4] .-= 1
    @test d[3,4] == [4,8]
end
let identity = error, x = [1,2,3]
    x .= 1 # make sure it goes to broadcast!(Base.identity, ...), not identity
    @test x == [1,1,1]
end

# make sure scalars are inlined, which causes f.(x,scalar) to lower to a "thunk"
import Base.Meta: isexpr
@test isexpr(Meta.lower(Main, :(f.(x,1))), :thunk)
@test isexpr(Meta.lower(Main, :(f.(x,1.0))), :thunk)
@test isexpr(Meta.lower(Main, :(f.(x,$π))), :thunk)
@test isexpr(Meta.lower(Main, :(f.(x,"hello"))), :thunk)
@test isexpr(Meta.lower(Main, :(f.(x,$("hello")))), :thunk)

# PR #17623: Fused binary operators
@test [true] .* [true] == [true]
@test [1,2,3] .|> (x->x+1) == [2,3,4]
let g = Int[], ⊕ = (a,b) -> let c=a+2b; push!(g, c); c; end
    @test [1,2,3] .⊕ [10,11,12] .⊕ [100,200,300] == [221,424,627]
    @test g == [21,221,24,424,27,627] # test for loop fusion
end

# Fused unary operators
@test .√[3,4,5] == sqrt.([3,4,5])
@test .![true, true, false] == [false, false, true]
@test .-[1,2,3] == -[1,2,3] == .+[-1,-2,-3] == [-1,-2,-3]

# PR 16988
@test Base.promote_op(+, Bool) === Int
@test isa(broadcast(+, [true]), Array{Int,1})

# issue #17304
let foo = [[1,2,3],[4,5,6],[7,8,9]]
    @test max.(foo...) == broadcast(max, foo...) == [7,8,9]
end

# Issue 17314
@test broadcast(x->log(log(log(x))), [1000]) == [log(log(log(1000)))]
let f17314 = x -> x < 0 ? false : x
    @test eltype(broadcast(f17314, 1:3)) === Int
    @test eltype(broadcast(f17314, -1:1)) === Integer
    @test eltype(broadcast(f17314, Int[])) === Integer
end
let io = IOBuffer()
    broadcast(x->print(io,x), 1:5) # broadcast with side effects
    @test take!(io) == [0x31,0x32,0x33,0x34,0x35]
end

# Issue 18176
let f18176(a, b, c) = a + b + c
    @test f18176.(1.0:2, 3, 4) == f18176.(3.0, 1.0:2, 4.0) == broadcast(f18176, 3, 4, 1.0:2)
end

# Issue #17984
let A17984 = []
    @test isa(abs.(A17984), Array{Any,1})
end

# Issue #16966
@test parse.(Int, "1") == 1
@test parse.(Int, ["1", "2"]) == [1, 2]
@test trunc.((Int,), [1.2, 3.4]) == [1, 3]
@test abs.((1, -2)) == (1, 2)
@test broadcast(+, 1.0, (0, -2.0)) == (1.0,-1.0)
@test broadcast(+, 1.0, (0, -2.0), [1]) == [2.0, 0.0]
@test broadcast(*, ["Hello"], ", ", ["World"], "!") == ["Hello, World!"]
let s = "foo"
    @test s .* ["bar", "baz"] == ["foobar", "foobaz"] == "foo" .* ["bar", "baz"]
end

# Ensure that even strange constructors that break `T(x)::T` work with broadcast
struct StrangeType18623 end
StrangeType18623(x) = x
StrangeType18623(x,y) = (x,y)
@test @inferred(broadcast(StrangeType18623, 1:3)) == [1,2,3]
@test @inferred(broadcast(StrangeType18623, 1:3, 4:6)) == [(1,4),(2,5),(3,6)]

@test typeof(Int.(Number[1, 2, 3])) === typeof((x->Int(x)).(Number[1, 2, 3]))

@test @inferred(broadcast(CartesianIndex, 1:2)) == [CartesianIndex(1), CartesianIndex(2)]
@test @inferred(broadcast(CartesianIndex, 1:2, 3:4)) == [CartesianIndex(1,3), CartesianIndex(2,4)]

# Issue 18622
@test @inferred(broadcast(muladd, [1.0], [2.0], [3.0])) == [5.0]
@test @inferred(broadcast(tuple, 1:3, 4:6, 7:9)) == [(1,4,7), (2,5,8), (3,6,9)]

# 19419
@test @inferred(broadcast(round, Int, [1])) == [1]

# https://discourse.julialang.org/t/towards-broadcast-over-combinations-of-sparse-matrices-and-scalars/910
let
    f(A, n) = broadcast(x -> +(x, n), A)
    @test @inferred(f([1.0], 1)) == [2.0]
    g() = (a = 1; Broadcast.combine_eltypes(x -> x + a, (1.0,)))
    @test @inferred(g()) === Float64
end

# Ref as 0-dimensional array for broadcast
@test (-).(C_NULL, C_NULL)::UInt == 0
@test (+).(1, Ref(2)) == 3
@test (+).(Ref(1), Ref(2)) == 3
@test (+).([[0,2], [1,3]], Ref{Vector{Int}}([1,-1])) == [[1,1], [2,2]]

# Check that broadcast!(f, A) populates A via independent calls to f (#12277, #19722),
# and similarly for broadcast!(f, A, numbers...) (#19799).
@test let z = 1; A = broadcast!(() -> z += 1, zeros(2)); A[1] != A[2]; end
@test let z = 1; A = broadcast!(x -> z += x, zeros(2), 1); A[1] != A[2]; end

## broadcasting for custom AbstractArray
abstract type ArrayData{T,N} <: AbstractArray{T,N} end
Base.getindex(A::ArrayData, i::Integer...) = A.data[i...]
Base.setindex!(A::ArrayData, v::Any, i::Integer...) = setindex!(A.data, v, i...)
Base.size(A::ArrayData) = size(A.data)
Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{A}}, ::Type{T}) where {A,T} =
    A(Array{T}(undef, size(bc)))

struct Array19745{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:Array19745} = Broadcast.ArrayStyle{Array19745}()

# Two specialized broadcast rules with no declared precedence
struct AD1{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD1} = Broadcast.ArrayStyle{AD1}()
struct AD2{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD2} = Broadcast.ArrayStyle{AD2}()

# Two specialized broadcast rules with explicit precedence
struct AD1P{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD1P} = Broadcast.ArrayStyle{AD1P}()
struct AD2P{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD2P} = Broadcast.ArrayStyle{AD2P}()

Base.BroadcastStyle(a1::Broadcast.ArrayStyle{AD1P}, ::Broadcast.ArrayStyle{AD2P}) = a1

# Two specialized broadcast rules where users unnecessarily
# define `BroadcastStyle` for both argument orders (but do so consistently)
struct AD1B{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD1B} = Broadcast.ArrayStyle{AD1B}()
struct AD2B{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD2B} = Broadcast.ArrayStyle{AD2B}()

Base.BroadcastStyle(a1::Broadcast.ArrayStyle{AD1B}, a2::Broadcast.ArrayStyle{AD2B}) = a1
Base.BroadcastStyle(a2::Broadcast.ArrayStyle{AD2B}, a1::Broadcast.ArrayStyle{AD1B}) = a1

# Two specialized broadcast rules with conflicting precedence
struct AD1C{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD1C} = Broadcast.ArrayStyle{AD1C}()
struct AD2C{T,N} <: ArrayData{T,N}
    data::Array{T,N}
end
Base.BroadcastStyle(::Type{T}) where {T<:AD2C} = Broadcast.ArrayStyle{AD2C}()

Base.BroadcastStyle(a1::Broadcast.ArrayStyle{AD1C}, a2::Broadcast.ArrayStyle{AD2C}) = a1
Base.BroadcastStyle(a2::Broadcast.ArrayStyle{AD2C}, a1::Broadcast.ArrayStyle{AD1C}) = a2

# A Custom type with specific dimensionality
struct AD2Dim{T} <: ArrayData{T,2}
    data::Array{T,2}
end
struct AD2DimStyle <: Broadcast.AbstractArrayStyle{2}; end
AD2DimStyle(::Val{2}) = AD2DimStyle()
AD2DimStyle(::Val{N}) where {N} = Broadcast.DefaultArrayStyle{N}()
Base.similar(bc::Broadcast.Broadcasted{AD2DimStyle}, ::Type{T}) where {T} =
    AD2Dim(Array{T}(undef, size(bc)))
Base.BroadcastStyle(::Type{T}) where {T<:AD2Dim} = AD2DimStyle()

@testset "broadcasting for custom AbstractArray" begin
    a  = randn(10)
    aa = Array19745(a)
    fadd(aa) = aa .+ 1
    fadd2(aa) = aa .+ 1 .* 2
    fadd3(aa) = aa .+ [missing; 1:9]
    fprod(aa) = aa .* aa'
    @test a .+ 1  == @inferred(fadd(aa))
    @test a .+ 1 .* 2  == @inferred(fadd2(aa))
    @test a .* a' == @inferred(fprod(aa))
    @test isequal(a .+ [missing; 1:9], fadd3(aa))
    @test Core.Compiler.return_type(fadd3, Tuple{typeof(aa),}) <: Array19745{<:Union{Float64, Missing}}
    @test isa(aa .+ 1, Array19745)
    @test isa(aa .+ 1 .* 2, Array19745)
    @test isa(aa .* aa', Array19745)
    @test isa(aa .* [missing; 1:9], Array19745)
    a1 = AD1(rand(2,3))
    a2 = AD2(rand(2))
    @test a1 .+ 1 isa AD1
    @test a2 .+ 1 isa AD2
    @test a1 .+ 1 .* 2 isa AD1
    @test a2 .+ 1 .* 2 isa AD2
    @test a1 .+ a2 isa Array
    @test a2 .+ a1 isa Array
    @test a1 .+ a2 .+ a1 isa Array
    @test a1 .+ a2 .+ a2 isa Array
    a1 = AD1P(rand(2,3))
    a2 = AD2P(rand(2))
    @test a1 .+ 1 isa AD1P
    @test a2 .+ 1 isa AD2P
    @test a1 .+ 1 .* 2 isa AD1P
    @test a2 .+ 1 .* 2 isa AD2P
    @test a1 .+ a2 isa AD1P
    @test a2 .+ a1 isa AD1P
    @test a1 .+ a2 .+ a1 isa AD1P
    @test a1 .+ a2 .+ a2 isa AD1P
    a1 = AD1B(rand(2,3))
    a2 = AD2B(rand(2))
    @test a1 .+ 1 isa AD1B
    @test a2 .+ 1 isa AD2B
    @test a1 .+ 1 .* 2 isa AD1B
    @test a2 .+ 1 .* 2 isa AD2B
    @test a1 .+ a2 isa AD1B
    @test a2 .+ a1 isa AD1B
    @test a1 .+ a2 .+ a1 isa AD1B
    @test a1 .+ a2 .+ a2 isa AD1B
    a1 = AD1C(rand(2,3))
    a2 = AD2C(rand(2))
    @test a1 .+ 1 isa AD1C
    @test a2 .+ 1 isa AD2C
    @test a1 .+ 1 .* 2 isa AD1C
    @test a2 .+ 1 .* 2 isa AD2C
    @test_throws ErrorException a1 .+ a2
    a2d = AD2Dim(rand(2, 3))
    a2 = AD2(rand(2))
    @test a2d .+ 1 isa AD2Dim
    @test a2d .+ a2 isa Matrix
    @test a2d .+ (1:2) isa AD2Dim
    @test a2d .+ ones(2, 3) isa AD2Dim
    @test a2d .+ ones(2, 3, 4) isa Array{Float64, 3}
end

# broadcast should only "peel off" one container layer
@test getindex.([Ref(1), Ref(2)]) == [1, 2]
let io = IOBuffer()
    broadcast(x -> print(io, x), [Ref(1.0)])
    @test String(take!(io)) == "Base.RefValue{Float64}(1.0)"
end

# Test that broadcast's promotion mechanism handles closures accepting more than one argument.
# (See issue #19641 and referenced issues and pull requests.)
let f() = (a = 1; Broadcast.combine_eltypes((x, y) -> x + y + a, (1.0, 1.0)))
    @test @inferred(f()) == Float64
end

@testset "broadcast resulting in BitArray" begin
    let f(x) = x ? true : "false"
        ba = f.([true])
        @test ba isa BitArray
        @test ba == [true]
        a = f.([false])
        @test a isa Array{String}
        @test a == ["false"]
        @test f.([true, false]) == [true, "false"]
    end
end

@testset "convert behavior of logical broadcast" begin
    a = mod.(1:4, 2)
    @test !isa(a, BitArray)
    for T in (Array{Bool}, BitArray)
        la = T(a)
        la .= mod.(0:3, 2)
        @test la == [false; true; false; true]
    end
end

# Test that broadcast treats type arguments as scalars, i.e. containertype yields Any,
# even for subtypes of abstract array. (https://github.com/JuliaStats/DataArrays.jl/issues/229)
@testset "treat type arguments as scalars, DataArrays issue 229" begin
    @test Broadcast.combine_styles(Broadcast.broadcastable(AbstractArray)) == Base.Broadcast.DefaultArrayStyle{0}()
    @test broadcast(==, [1], AbstractArray) == BitArray([false])
    @test broadcast(==, 1, AbstractArray) == false
end

@testset "broadcasting falls back to iteration (issues #26421, #19577, #23746)" begin
    @test_throws ArgumentError broadcast(identity, Dict(1=>2))
    @test_throws ArgumentError broadcast(identity, (a=1, b=2))
    @test_throws ArgumentError length.(Dict(1 => BitSet(1:2), 2 => BitSet(1:3)))
    @test_throws MethodError broadcast(identity, Base)

    @test broadcast(identity, Iterators.filter(iseven, 1:10)) == 2:2:10
    d = Dict([1,2] => 1.1, [3,2] => 0.1)
    @test length.(keys(d)) == [2,2]
    @test Set(exp.(Set([1,2,3]))) == Set(exp.([1,2,3]))
end

# Test that broadcasting identity where the input and output Array shapes do not match
# yields the correct result, not merely a partial copy. See pull request #19895 for discussion.
let N = 5
    @test iszero(fill(1, N, N) .= zeros(N, N))
    @test iszero(fill(1, N, N) .= zeros(N, 1))
    @test iszero(fill(1, N, N) .= zeros(1, N))
    @test iszero(fill(1, N, N) .= zeros(1, 1))
end

@testset "test broadcast for matrix of matrices" begin
    A = fill([0 0; 0 0], 4, 4)
    A[1:3,1:3] .= [[1 1; 1 1]]
    @test all(A[1:3,1:3] .== [[1 1; 1 1]])
end

# Test that broadcast does not confuse eltypes. See also
# https://github.com/JuliaLang/julia/issues/21325
@testset "eltype confusion (#21325)" begin
    foo(x::Char, y::Int) = 0
    foo(x::String, y::Int) = "hello"
    @test broadcast(foo, "x", [1, 2, 3]) == ["hello", "hello", "hello"]

    @test isequal(
        [Set([1]), Set([2])] .∪ Ref(Set([3])),
        [Set([1, 3]), Set([2, 3])])
end

# A bare bones custom type that supports broadcast
struct Foo26601{T}
    data::T
end
Base.axes(f::Foo26601) = axes(f.data)
Base.getindex(f::Foo26601, i...) = getindex(f.data, i...)
Base.ndims(::Type{Foo26601{T}}) where {T} = ndims(T)
Base.Broadcast.broadcastable(f::Foo26601) = f
@testset "barebones custom object broadcasting" begin
    for d in (rand(Float64, ()), rand(5), rand(5,5), rand(5,5,5))
        f = Foo26601(d)
        @test f .* 2 == d .* 2
        @test f .* (1:5) == d .* (1:5)
        @test f .* reshape(1:25,5,5) == d .* reshape(1:25,5,5)
        @test sqrt.(f) == sqrt.(d)
        @test f .* (1,2,3,4,5) == d .* (1,2,3,4,5)
    end
end

@testset "broadcast resulting in tuples" begin
    # Issue #21291
    let t = (0, 1, 2)
        o = 1
        @test @inferred(broadcast(+, t, o)) == (1, 2, 3)
    end

    # Issue #23647
    @test (1, 2, 3) .+ (1,) == (1,) .+ (1, 2, 3) == (2, 3, 4)
    @test (1,) .+ () == () .+ (1,) == () .+ () == ()
    @test (1, 2) .+ (1, 2) == (2, 4)
    @test_throws DimensionMismatch (1, 2) .+ (1, 2, 3)
end

@testset "broadcasted assignment from tuples and tuple styles (#33020)" begin
    a = zeros(3)
    @test_throws DimensionMismatch a .= (1,2)
    @test_throws DimensionMismatch a .= sqrt.((1,2))
    a .= (1,)
    @test all(==(1), a)
    a .= sqrt.((2,))
    @test all(==(√2), a)
    a = zeros(3, 2)
    @test_throws DimensionMismatch a .= (1,2)
    @test_throws DimensionMismatch a .= sqrt.((1,2))
    a .= (1,)
    @test all(==(1), a)
    a .= sqrt.((2,))
    @test all(==(√2), a)
    a .= (1,2,3)
    @test a == [1 1; 2 2; 3 3]
end

@testset "scalar .= and promotion" begin
    A = [[1, 2, 3], 4:5, 6]
    @test A isa Vector{Any}
    A[1] .= 0
    @test A[1] == [0, 0, 0]
    @test_throws Base.CanonicalIndexError A[2] .= 0
    @test_throws MethodError A[3] .= 0
    A = [[1, 2, 3], 4:5]
    A[1] .= 0
    @test A[1] isa Vector{Int}
    @test A[2] isa UnitRange
    @test A[1] == [0,0,0]
    @test_throws Base.CanonicalIndexError A[2] .= 0
end

# Issue #22180
@test convert.(Any, [1, 2]) == [1, 2]

# Issue #24944
let n = 1
    @test ceil.(Int, n ./ (1,)) == (1,)
    @test ceil.(Int, 1 ./ (1,)) == (1,)
end

# Issue #29266
@testset "deprecated scalar-fill .=" begin
    a = fill(1, 10)
    @test_throws ArgumentError a[1:5] = 0

    x = randn(10)
    @test_throws ArgumentError x[x .> 0.0] = 0.0
end


# lots of splatting!
let x = [[1, 4], [2, 5], [3, 6]]
    y = .+(x..., .*(x..., x...)..., x[1]..., x[2]..., x[3]...)
    @test y == [14463, 14472]

    z = zeros(2)
    z .= .+(x..., .*(x..., x...)..., x[1]..., x[2]..., x[3]...)
    @test z == Float64[14463, 14472]
end

# Issue #21094
@generated function foo21094(out, x)
    quote
        out .= x .+ x
        out
    end
end
@test foo21094([0.0], [1.0]) == [2.0]

# Issue #22053
struct T22053
    t
end
Broadcast.BroadcastStyle(::Type{T22053}) = Broadcast.Style{T22053}()
Broadcast.axes(::T22053) = ()
Broadcast.broadcastable(t::T22053) = t
function Base.copy(bc::Broadcast.Broadcasted{Broadcast.Style{T22053}})
    all(x->isa(x, T22053), bc.args) && return 1
    return 0
end
Base.:*(::T22053, ::T22053) = 2
let x = T22053(1)
    @test x*x == 2
    @test x.*x == 1
end

# Issue https://github.com/JuliaLang/julia/pull/25377#discussion_r159956996
let X = Any[1,2]
    X .= nothing
    @test X[1] == X[2] == nothing
end

# Ensure that broadcast styles with custom indexing work
let X = zeros(2, 3)
    X .= (1, 2)
    @test X == [1 1 1; 2 2 2]
end

# issue #27988: inference of Broadcast.flatten
using .Broadcast: Broadcasted, cat_nested
let
    bc = Broadcasted(+, (Broadcasted(*, (1, 2)), Broadcasted(*, (Broadcasted(*, (3, 4)), 5))))
    @test @inferred(cat_nested(bc)) == (1,2,3,4,5)
    @test @inferred(Broadcast.materialize(Broadcast.flatten(bc))) == @inferred(Broadcast.materialize(bc)) == 62
    bc = Broadcasted(+, (Broadcasted(*, (1, Broadcasted(/, (2.0, 2.5)))), Broadcasted(*, (Broadcasted(*, (3, 4)), 5))))
    @test @inferred(cat_nested(bc)) == (1,2.0,2.5,3,4,5)
    @test @inferred(Broadcast.materialize(Broadcast.flatten(bc))) == @inferred(Broadcast.materialize(bc)) == 60.8
    # 1 .* 1 .- 1 .* 1 .^2 .+ 1 .* 1 .+ 1 .^ 3
    bc = Broadcasted(+, (Broadcasted(+, (Broadcasted(-, (Broadcasted(*, (1, 1)), Broadcasted(*, (1, Broadcasted(Base.literal_pow, (Ref(^), 1, Ref(Val(2)))))))), Broadcasted(*, (1, 1)))), Broadcasted(Base.literal_pow, (Base.RefValue{typeof(^)}(^), 1, Base.RefValue{Val{3}}(Val{3}())))))
    @test @inferred(Broadcast.materialize(Broadcast.flatten(bc))) == @inferred(Broadcast.materialize(bc)) == 2
    # @. 1 + 1 * (1 + 1 + 1 + 1)
    bc = Broadcasted(+, (1, Broadcasted(*, (1, Broadcasted(+, (1, 1, 1, 1))))))
    @test @inferred(cat_nested(bc)) == (1, 1, 1, 1, 1, 1) # `cat_nested` failed to infer this
    @test @inferred(Broadcast.materialize(Broadcast.flatten(bc))) == Broadcast.materialize(bc)
    # @. 1 + (1 + 1) + 1 + (1 + 1) + 1 + (1 + 1) + 1
    bc = Broadcasted(+, (1, Broadcasted(+, (1, 1)), 1, Broadcasted(+, (1, 1)), 1, Broadcasted(+, (1, 1)), 1))
    @test @inferred(cat_nested(bc)) == (1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
    @test @inferred(Broadcast.materialize(Broadcast.flatten(bc))) == Broadcast.materialize(bc)
    bc = Broadcasted(Float32, (Broadcasted(+, (1, 1)),))
    @test @inferred(Broadcast.materialize(Broadcast.flatten(bc))) == Broadcast.materialize(bc)
end

let
    bc = Broadcasted(+, (Broadcasted(*, ([1, 2, 3], 4)), 5))
    @test isbits(Broadcast.flatten(bc).f)
end

# Issue #26127: multiple splats in a fused dot-expression
let f(args...) = *(args...)
    x, y, z = (1,2), 3, (4, 5)
    @test f.(x..., y, z...) == broadcast(f, x..., y, z...) == 120
    @test f.(x..., f.(x..., y, z...), y, z...) == broadcast(f, x..., broadcast(f, x..., y, z...), y, z...) == 120*120
end

@testset "Issue #27911: Broadcasting over collections with big indices" begin
    @test iszero.(Int128(0):Int128(2)) == [true, false, false]
    @test iszero.((Int128(0):Int128(2)) .- 1) == [false, true, false]
    @test iszero.(big(0):big(2)) == [true, false, false]
    @test iszero.((big(0):big(2)) .- 1) == [false, true, false]
end

@testset "Issue #27775: Broadcast!ing over nested scalar operations" begin
    a = zeros(2)
    a .= 1 ./ (1 + 2)
    @test a == [1/3, 1/3]
    a .= 1 ./ (1 .+ 3)
    @test a == [1/4, 1/4]
    a .= sqrt.(1 ./ 2)
    @test a == [sqrt(1/2), sqrt(1/2)]
    rng = MersenneTwister(1234)
    a .= rand.((rng,))
    rng = MersenneTwister(1234)
    @test a == [rand(rng), rand(rng)]
    @test a[1] != a[2]
    rng = MersenneTwister(1234)
    broadcast!(rand, a, (rng,))
    rng = MersenneTwister(1234)
    @test a == [rand(rng), rand(rng)]
    @test a[1] != a[2]
end

# Issue #27446: Broadcasting pair operator
let
    c = ["foo", "bar"]
    d = [1,2]
    @test Dict(c .=> d) == Dict("foo" => 1, "bar" => 2)
end

# Broadcasted iterable/indexable APIs
let
    bc = Broadcast.instantiate(Broadcast.broadcasted(+, zeros(5), 5))
    @test IndexStyle(bc) == IndexLinear()
    @test eachindex(bc) === Base.OneTo(5)
    @test length(bc) === 5
    @test ndims(bc) === 1
    @test ndims(typeof(bc)) === 1
    @test bc[1] === bc[CartesianIndex((1,))] === 5.0
    @test copy(bc) == [v for v in bc] == collect(bc)
    @test eltype(copy(bc)) == eltype([v for v in bc]) == eltype(collect(bc))
    @test ndims(copy(bc)) == ndims([v for v in bc]) == ndims(collect(bc)) == ndims(bc)

    bc = Broadcast.instantiate(Broadcast.broadcasted(+, zeros(5), 5*ones(1, 4)))
    @test IndexStyle(bc) == IndexCartesian()
    @test eachindex(bc) === CartesianIndices((Base.OneTo(5), Base.OneTo(4)))
    @test length(bc) === 20
    @test ndims(bc) === 2
    @test ndims(typeof(bc)) === 2
    @test bc[1,1] == bc[CartesianIndex((1,1))] === 5.0
    @test copy(bc) == [v for v in bc] == collect(bc)
    @test eltype(copy(bc)) == eltype([v for v in bc]) == eltype(collect(bc))
    @test ndims(copy(bc)) == ndims([v for v in bc]) == ndims(collect(bc)) == ndims(bc)

    struct MyFill{T,N} <: AbstractArray{T,N}
        val :: T
        sz :: NTuple{N,Int}
    end
    Base.size(M::MyFill) = M.sz
    function Base.getindex(M::MyFill{<:Any,N}, i::Vararg{Int, N}) where {N}
        checkbounds(M, i...)
        M.val
    end
    Base.IndexStyle(::Type{<:Base.Broadcast.Broadcasted{<:Any,<:Any,<:Any,<:Tuple{MyFill}}}) = IndexLinear()
    bc = Broadcast.instantiate(Broadcast.broadcasted(+, MyFill(2, (3,3))))
    @test IndexStyle(bc) == IndexLinear()
    @test eachindex(bc) === Base.OneTo(9)
    @test bc[2] == bc[CartesianIndex(2,1)]

    for bc in Any[
                Broadcast.broadcasted(+, collect(reshape(1:9, 3, 3)), 1:3), # IndexCartesian
                Broadcast.broadcasted(+, [1,2], 2), # IndexLinear
            ]
        bci = Broadcast.instantiate(bc)
        for (Ilin, Icart) in zip(eachindex(IndexLinear(), bc), eachindex(IndexCartesian(), bc))
            @test bc[Ilin] == bc[Icart]
        end
    end
end

# issue 43847: collect preserves shape of broadcasted
let
    bc = Broadcast.broadcasted(*, [1 2; 3 4], 2)
    @test collect(Iterators.product(bc, bc)) == collect(Iterators.product(copy(bc), copy(bc)))

    a1 = AD1(rand(2,3))
    bc1 = Broadcast.broadcasted(*, a1, 2)
    @test collect(Iterators.product(bc1, bc1)) == collect(Iterators.product(copy(bc1), copy(bc1)))

    # using ndims of second arg
    bc2 = Broadcast.broadcasted(*, 2, a1)
    @test collect(Iterators.product(bc2, bc2)) == collect(Iterators.product(copy(bc2), copy(bc2)))

    # >2 args
    bc3 = Broadcast.broadcasted(*, a1, 3, a1)
    @test collect(Iterators.product(bc3, bc3)) == collect(Iterators.product(copy(bc3), copy(bc3)))

    # including a tuple and custom array type
    bc4 = Broadcast.broadcasted(*, (1,2,3), AD1(rand(3)))
    @test collect(Iterators.product(bc4, bc4)) == collect(Iterators.product(copy(bc4), copy(bc4)))

    # testing ArrayConflict
    @test Broadcast.broadcasted(+, AD1(rand(3)), AD2(rand(3))) isa Broadcast.Broadcasted{Broadcast.ArrayConflict}
    @test Broadcast.broadcasted(+, AD1(rand(3)), AD2(rand(3))) isa Broadcast.Broadcasted{<:Broadcast.AbstractArrayStyle{Any}}

    @test @inferred(Base.IteratorSize(Broadcast.broadcasted(+, (1,2,3), a1, zeros(3,3,3)))) === Base.HasShape{3}()

    @test @inferred(Base.IteratorSize(Base.broadcasted(randn))) === Base.HasShape{0}()

    # inference on nested
    bc = Base.broadcasted(+, AD1(randn(3)), AD1(randn(3)))
    bc_nest = Base.broadcasted(+, bc , bc)
    @test @inferred(Base.IteratorSize(bc_nest)) === Base.HasShape{1}()
 end

# issue #31295
let a = rand(5), b = rand(5), c = copy(a)
    view(identity(a), 1:3) .+= view(b, 1:3)
    @test a == [(c+b)[1:3]; c[4:5]]

    x = [1]
    x[[1,1]] .+= 1
    @test x == [2]
end

@testset "broadcasted mapreduce" begin
    xs = 1:10
    ys = 1:2:20
    bc = Broadcast.instantiate(Broadcast.broadcasted(*, xs, ys))
    @test IndexStyle(bc) == IndexLinear()
    @test sum(bc) == mapreduce(Base.splat(*), +, zip(xs, ys))

    xs2 = reshape(xs, 1, :)
    ys2 = reshape(ys, 1, :)
    bc = Broadcast.instantiate(Broadcast.broadcasted(*, xs2, ys2))
    @test IndexStyle(bc) == IndexCartesian()
    @test sum(bc) == mapreduce(Base.splat(*), +, zip(xs, ys))

    xs = 1:5:3*5
    ys = 1:4:3*4
    bc = Broadcast.instantiate(
        Broadcast.broadcasted(iseven, Broadcast.broadcasted(-, xs, ys)))
    @test count(bc) == count(iseven, map(-, xs, ys))

    xs = reshape(1:6, (2, 3))
    ys = 1:2
    bc = Broadcast.instantiate(Broadcast.broadcasted(*, xs, ys))
    @test reduce(+, bc; dims=1, init=0) == [5 11 17]

    # Let's test that `Broadcasted` actually hits the efficient
    # `mapreduce` method as intended.  We are going to invoke `reduce`
    # with this *NON-ASSOCIATIVE* binary operator to see what
    # associativity is chosen by the implementation:
    paren = (x, y) -> "($x,$y)"
    # Next, we construct data `xs` such that `length(xs)` is greater
    # than short array cutoff of `_mapreduce`:
    alphabets = 'a':'z'
    blksize = Base.pairwise_blocksize(identity, paren) ÷ length(alphabets)
    xs = repeat(alphabets, 2 * blksize)
    @test length(xs) > blksize
    # So far we constructed the data `xs` and reducing function
    # `paren` such that `reduce` and `foldl` results are different.
    # That is to say, this `reduce` does not hit the fall-back `foldl`
    # branch:
    @test foldl(paren, xs) != reduce(paren, xs)

    # Now let's try it with `Broadcasted`:
    bcraw = Broadcast.broadcasted(identity, xs)
    bc = Broadcast.instantiate(bcraw)
    # If `Broadcasted` has `IndexLinear` style, it should hit the
    # `reduce` branch:
    @test IndexStyle(bc) == IndexLinear()
    @test reduce(paren, bc) == reduce(paren, xs)
    # If `Broadcasted` does not have `IndexLinear` style, it should
    # hit the `foldl` branch:
    @test IndexStyle(bcraw) == IndexCartesian()
    @test reduce(paren, bcraw) == foldl(paren, xs)

    # issue #41055
    bc = Broadcast.instantiate(Broadcast.broadcasted(Base.literal_pow, Ref(^), [1,2], Ref(Val(2))))
    @test sum(bc, dims=1, init=0) == [5]
    bc = Broadcast.instantiate(Broadcast.broadcasted(*, ['a','b'], 'c'))
    @test prod(bc, dims=1, init="") == ["acbc"]

    a = rand(-10:10,32,4); b = rand(-10:10,32,4)
    bc = Broadcast.instantiate(Broadcast.broadcasted(+,a,b))
    @test sum(bc; dims = 1, init = 0.0) == sum(collect(bc); dims = 1, init = 0.0)
end

# treat Pair as scalar:
@test replace.(split("The quick brown fox jumps over the lazy dog"), r"[aeiou]"i => "_") ==
      ["Th_", "q__ck", "br_wn", "f_x", "j_mps", "_v_r", "th_", "l_zy", "d_g"]

# 28680
@test 1 .+ 1 .+  (1, 2) == (3, 4)

# PR #35260 no allocations in simple broadcasts
u = rand(100)
k1 = similar(u)
k2 = similar(u)
k3 = similar(u)
k4 = similar(u)
f(a,b,c,d,e) = @. a = a + 1*(b+c+d+e)
@allocated f(u,k1,k2,k3,k4)
@test (@allocated f(u,k1,k2,k3,k4)) == 0

ret =  @macroexpand @.([Int, Number] <: Real)
@test ret == :([Int, Number] .<: Real)

ret =  @macroexpand @.([Int, Number] >: Real)
@test ret == :([Int, Number] .>: Real)

# Threw mapany not defined
p = rand(4,4); r = rand(2,4);
p0 = copy(p)
@views @. p[1:2, :] += r
@test p[1:2, :] ≈ p0[1:2, :] + r

@test identity(.+) == Broadcast.BroadcastFunction(+)
@test identity.(.*) == Broadcast.BroadcastFunction(*)
@test map(.+, [[1,2], [3,4]], [5, 6]) == [[6,7], [9,10]]
@test repr(.!) == "Base.Broadcast.BroadcastFunction(!)"
@test eval(:(.+)) == Base.BroadcastFunction(+)

@testset "Issue #5187: Broadcasting of short-circuiting ops" begin
    ex = Meta.parse("A .< 1 .|| A .> 2")
    @test ex == :((A .< 1) .|| (A .> 2))
    @test ex.head == :.||
    ex = Meta.parse("A .< 1 .&& A .> 2")
    @test ex == :((A .< 1) .&& (A .> 2))
    @test ex.head == :.&&

    A = -1:4
    @test (A .< 1 .|| A .> 2) == [true, true, false, false, true, true]
    @test (A .>= 1 .&& A .<= 2) == [false, false, true, true, false, false]

    mutable struct F5187; x; end
    (f::F5187)(x) = (f.x += x)
    @test (iseven.(1:4) .&& (F5187(0)).(ones(4))) == [false, 1, false, 2]
    @test (iseven.(1:4) .|| (F5187(0)).(ones(4))) == [1, true, 2, true]
    r = 1:4; o = ones(4); f = F5187(0);
    @test (@. iseven(r) && f(o)) == [false, 1, false, 2]
    @test (@. iseven(r) || f(o)) == [3, true, 4, true]

    @test (iseven.(1:8) .&& iseven.((F5187(0)).(ones(8))) .&& (F5187(0)).(ones(8))) == [false,false,false,1,false,false,false,2]
    @test (iseven.(1:8) .|| iseven.((F5187(0)).(ones(8))) .|| (F5187(0)).(ones(8))) == [1,true,true,true,2,true,true,true]
    r = 1:8; o = ones(8); f1 = F5187(0); f2 = F5187(0)
    @test (@. iseven(r) && iseven(f1(o)) && f2(o)) == [false,false,false,1,false,false,false,2]
    @test (@. iseven(r) || iseven(f1(o)) || f2(o)) == [3,true,true,true,4,true,true,true]
    @test (iseven.(1:8) .&& iseven.((F5187(0)).(ones(8))) .&& (F5187(0)).(ones(8))) == [false,false,false,1,false,false,false,2]
    @test (iseven.(1:8) .|| iseven.((F5187(0)).(ones(8))) .|| (F5187(0)).(ones(8))) == [1,true,true,true,2,true,true,true]
end

@testset "Issue #28382: inferrability of broadcast with Union eltype" begin
    @test isequal([1, 2] .+ [3.0, missing], [4.0, missing])
    @test Core.Compiler.return_type(broadcast, Tuple{typeof(+), Vector{Int},
                                                     Vector{Union{Float64, Missing}}}) ==
        Union{Vector{Missing}, Vector{Union{Missing, Float64}}, Vector{Float64}}
    @test Core.Compiler.return_type(+, Tuple{Vector{Int},
                                             Vector{Union{Float64, Missing}}}) ==
        Union{Vector{Missing}, Vector{Union{Missing, Float64}}, Vector{Float64}}
    @test isequal(tuple.([1, 2], [3.0, missing]), [(1, 3.0), (2, missing)])
    @test Core.Compiler.return_type(broadcast, Tuple{typeof(tuple), Vector{Int},
                                                     Vector{Union{Float64, Missing}}}) ==
        Union{Vector{Tuple{Int, Missing}}, Vector{Tuple{Int, Any}}, Vector{Tuple{Int, Float64}}}
    # Check that corner cases do not throw an error
    @test isequal(broadcast(x -> x === 1 ? nothing : x, [1, 2, missing]),
                  [nothing, 2, missing])
    @test isequal(broadcast(x -> x === 1 ? nothing : x, Any[1, 2, 3.0, missing]),
                  [nothing, 2, 3, missing])
    @test broadcast((x,y)->(x==1 ? 1.0 : x, y), [1 2 3], ["a", "b", "c"]) ==
        [(1.0, "a") (2, "a") (3, "a")
         (1.0, "b") (2, "b") (3, "b")
         (1.0, "c") (2, "c") (3, "c")]
    @test typeof.([iszero, isdigit]) == [typeof(iszero), typeof(isdigit)]
    @test typeof.([iszero, iszero]) == [typeof(iszero), typeof(iszero)]
    @test isequal(identity.(Vector{<:Union{Int, Missing}}[[1, 2],[missing, 1]]),
                  [[1, 2],[missing, 1]])
    @test broadcast(i -> ((x=i, y=(i==1 ? 1 : "a")), 3), 1:4) isa
        Vector{Tuple{NamedTuple{(:x, :y)}, Int}}
end

@testset "Issue #28382: eltype inconsistent with getindex" begin
    struct Cyclotomic <: Number
    end

    Base.eltype(::Type{<:Cyclotomic}) = Tuple{Int,Int}

    Base.:*(c::T, x::Cyclotomic) where {T<:Real} = [1, 2]
    Base.:*(x::Cyclotomic, c::T) where {T<:Real} = [1, 2]

    @test Cyclotomic() .* [2, 3] == [[1, 2], [1, 2]]
end

@testset "inplace broadcast with trailing singleton dims" begin
    for (a, b, c) in (([1, 2], reshape([3 4], :, 1), reshape([5, 6], :, 1, 1)),
            ([1 2; 3 4], reshape([5 6; 7 8], 2, 2, 1), reshape([9 10; 11 12], 2, 2, 1, 1)))

        a_ = copy(a)
        a_ .= b
        @test a_ == dropdims(b, dims=(findall(==(1), size(b))...,))

        a_ = copy(a)
        a_ .= b
        @test a_ == dropdims(b, dims=(findall(==(1), size(b))...,))

        a_ = copy(a)
        a_ .= b .+ c
        @test a_ == dropdims(b .+ c, dims=(findall(==(1), size(c))...,))

        a_ = copy(a)
        a_ .*= c
        @test a_ == dropdims(a .* c, dims=(findall(==(1), size(c))...,))
    end
end

@testset "Issue #40309: still gives a range after #40320" begin
    @test Base.broadcasted_kwsyntax(+, [1], [2]) isa Broadcast.Broadcasted{<:Any, <:Any, typeof(+)}
    @test Broadcast.BroadcastFunction(+)(2:3, 2:3) == 4:2:6
    @test Broadcast.BroadcastFunction(+)(2:3, 2:3) isa AbstractRange
end

@testset "#42063" begin
    buf = IOBuffer()
    @test println.(buf, [1,2,3]) == [nothing, nothing, nothing]
    @test String(take!(buf)) == "1\n2\n3\n"
end

@testset "Memory allocation inconsistency in broadcasting #41565" begin
    function test(y)
        y .= 0 .- y ./ (y.^2) # extra allocation
        return y
    end
    arr = rand(1000)
    @allocated test(arr)
    @test (@allocated test(arr)) <= 16
end

@testset "Fix type unstable .&& #43470" begin
    function test(x, y)
        return (x .> 0.0) .&& (y .> 0.0)
    end
    x = randn(2)
    y = randn(2)
    @inferred(test(x, y)) == [0, 0]
end

@testset "issue #45903, in place broadcast into a bit-masked bitmatrix" begin
    A = BitArray(ones(3,3))
    pos = randn(3,3)
    A[pos .< 0] .= false
    @test all(>=(0), pos[A])
    @test count(A) == count(>=(0), pos)
end

@testset "issue #38432: make CartesianIndex a broadcast scalar" begin
    @test CartesianIndex(1,2) .+ (CartesianIndex(3,4), CartesianIndex(5,6)) == (CartesianIndex(4, 6), CartesianIndex(6, 8))
    @test CartesianIndex(1,2) .+ [CartesianIndex(3,4), CartesianIndex(5,6)] == [CartesianIndex(4, 6), CartesianIndex(6, 8)]
end

struct MyBroadcastStyleWithField <: Broadcast.BroadcastStyle
    i::Int
end
# asymmetry intended
Base.BroadcastStyle(a::MyBroadcastStyleWithField, b::MyBroadcastStyleWithField) = a

@testset "issue #50937: styles that have fields" begin
    @test Broadcast.result_style(MyBroadcastStyleWithField(1), MyBroadcastStyleWithField(1)) ==
        MyBroadcastStyleWithField(1)
    @test_throws ErrorException Broadcast.result_style(MyBroadcastStyleWithField(1),
                                                       MyBroadcastStyleWithField(2))
    dest = [0, 0]
    dest .= Broadcast.Broadcasted(MyBroadcastStyleWithField(1), +, (1:2, 2:3))
    @test dest == [3, 5]
end

# test that `Broadcast` definition is defined as total and eligible for concrete evaluation
import Base.Broadcast: BroadcastStyle, DefaultArrayStyle
@test Base.infer_effects(BroadcastStyle, (DefaultArrayStyle{1},DefaultArrayStyle{2},)) |>
    Core.Compiler.is_foldable

f51129(v, x) = (1 .- (v ./ x) .^ 2)
@test @inferred(f51129([13.0], 6.5)) == [-3.0]

@testset "Docstrings" begin
    undoc = Docs.undocumented_names(Broadcast)
    @test_broken isempty(undoc)
    @test undoc == [:dotview]
end

@testset "broadcast for `AbstractArray` without `CartesianIndex` support" begin
    struct BVec52775 <: AbstractVector{Int}
        a::Vector{Int}
    end
    Base.size(a::BVec52775) = size(a.a)
    Base.getindex(a::BVec52775, i::Real) = a.a[i]
    Base.getindex(a::BVec52775, i) = error("unsupported index!")
    a = BVec52775([1,2,3])
    bc = Base.broadcasted(identity, a)
    @test bc[1] == bc[CartesianIndex(1)] == bc[1, CartesianIndex()]
    @test a .+ [1 2] == a.a .+ [1 2]
end
