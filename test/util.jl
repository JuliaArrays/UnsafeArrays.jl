# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

using UnsafeArrays
using Compat.Test


@testset "util" begin
    @testset "_sub_axes" begin
        @test @inferred(UnsafeArrays._sub_axes()) == ()
        @test @inferred(UnsafeArrays._sub_axes(1)) == ()
        @test @inferred(UnsafeArrays._sub_axes(2:5)) == (Base.OneTo(4),)
        @test @inferred(UnsafeArrays._sub_axes(Base.OneTo(5))) == (Base.OneTo(5),)
        @test @inferred(UnsafeArrays._sub_axes(4, 5, 6)) == ()
        @test @inferred(UnsafeArrays._sub_axes(1:4, 5, 6)) == (Base.OneTo(4),)
        @test @inferred(UnsafeArrays._sub_axes(1:4, 1:5, 6)) == (Base.OneTo(4), Base.OneTo(5))
        @test @inferred(UnsafeArrays._sub_axes(1:4, 1:5, 1:6)) == (Base.OneTo(4), Base.OneTo(5), Base.OneTo(6))
        @test @inferred(UnsafeArrays._sub_axes(1:4, 3, 1:6)) == (Base.OneTo(4), Base.OneTo(6))
        @test @inferred(UnsafeArrays._sub_axes(2, 1:5, 1:6)) == (Base.OneTo(5), Base.OneTo(6))
    end


    @testset "_sub_size" begin
        @test @inferred(UnsafeArrays._sub_size()) == ()
        @test @inferred(UnsafeArrays._sub_size(1)) == ()
        @test @inferred(UnsafeArrays._sub_size(2:5)) == (4,)
        @test @inferred(UnsafeArrays._sub_size(Base.OneTo(5))) == (5,)
        @test @inferred(UnsafeArrays._sub_size(4, 5, 6)) == ()
        @test @inferred(UnsafeArrays._sub_size(1:4, 5, 6)) == (4,)
        @test @inferred(UnsafeArrays._sub_size(1:4, 1:5, 6)) == (4, 5)
        @test @inferred(UnsafeArrays._sub_size(1:4, 1:5, 1:6)) == (4, 5, 6)
        @test @inferred(UnsafeArrays._sub_size(1:4, 3, 1:6)) == (4, 6)
        @test @inferred(UnsafeArrays._sub_size(2, 1:5, 1:6)) == (5, 6)
    end


    @testset "_require_one_based_indexing" begin
        @test @inferred(UnsafeArrays._require_one_based_indexing(rand(3, 5))) == nothing
        @test @inferred(UnsafeArrays._require_one_based_indexing(view(rand(3, 5), 2:3, 3:4))) == nothing
    end


    @testset "_noinline_nop" begin
        @test @inferred(UnsafeArrays._noinline_nop(())) == nothing
        @test @inferred(UnsafeArrays._noinline_nop((rand(3),))) == nothing
        @test @inferred(UnsafeArrays._noinline_nop((rand(3), rand(3, 5)))) == nothing
    end


    @testset "@gc_preserve" begin
        A = rand(4, 5)
        s = "foo"
        @test (UnsafeArrays.@gc_preserve 42) == 42
        @test (UnsafeArrays.@gc_preserve A size(A)) == (4, 5)
        @test (UnsafeArrays.@gc_preserve A s (size(A), s)) == ((4, 5), "foo")
    end
end
