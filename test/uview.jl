# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

using UnsafeArrays
using Compat
using Compat.Test
using Compat.Random
using Compat: axes


@testset "uview" begin
    function rand_array(::Type{T}, Val_N::Val{N}) where {T, N}
        sz_max = (8, 7, 5, 4, 5)
        sz = ntuple(i -> sz_max[i], Val_N)
        rand!(Array{T}(undef, sz...))
    end

    function rand_array(::Type{T}, Val_N::Val{N}) where {T<:Integer, N}
        sz_max = (8, 7, 5, 4, 5)
        sz = ntuple(i -> sz_max[i], Val_N)
        rand!(Array{T}(undef, sz...), 0:99)
    end

    function test_A(test_code::Function, ::Type{T}, Val_N::Val{N}) where {T, N}
        A = rand_array(T, Val_N)
        UnsafeArrays.@gc_preserve A test_code(A)
    end


    @testset "uview" begin
        test_A(Float64, Val(0)) do A
            @test typeof(@inferred(uview(A))) == UnsafeArray{Float64,0}

            @test uview(A) == A
            @test uview(A) == view(A)
        end

        test_A(Float32, Val(1)) do A
            @test typeof(@inferred(uview(A))) == UnsafeArray{Float32,1}
            @test typeof(@inferred(uview(A, :))) == UnsafeArray{Float32,1}
            @test typeof(@inferred(uview(A, 2))) == UnsafeArray{Float32,0}

            @test uview(A) == A
            @test uview(A, :) == view(A, :)
            @test uview(A, 2) == view(A, 2)

            @test_throws BoundsError uview(A, 2:9)
        end

        test_A(ComplexF32, Val(3)) do A
            @test typeof(@inferred(uview(A))) == UnsafeArray{ComplexF32,3}
            @test typeof(@inferred(uview(A, :, 2:4, 3))) == UnsafeArray{ComplexF32,2}
            @test typeof(@inferred(uview(A, :))) == UnsafeArray{ComplexF32,1}
            @test typeof(@inferred(uview(A, 2, 3, 4))) == UnsafeArray{ComplexF32,0}
            @static if VERSION < v"0.7.0-DEV"
                @test typeof(@inferred(uview(A, :, 2:4, :))) <: SubArray
            else
                # Inference fails on Julia v0.7, for some reason
                @test typeof(uview(A, :, 2:4, :)) <: SubArray
            end

            @test uview(A) == A
            @test uview(A, :, 2:4, 3) == view(A, :, 2:4, 3)
            @test uview(A, :) == view(A, :)
            @test uview(A, 2, 3, 4) == view(A, 2, 3, 4)
            @test uview(A, :, 2:4, :) == view(A, :, 2:4, :)

            @test_throws BoundsError uview(A, :, 2:9, 3)

            B = view(A, :, :, 3)

            @test typeof(@inferred(uview(B))) == UnsafeArray{ComplexF32,2}
            @test typeof(@inferred(uview(B, :, 2:4))) == UnsafeArray{ComplexF32,2}

            @test uview(B) == B
            @test uview(B, :, 2:4) == view(B, :, 2:4)

            C = uview(A, :, :, 3)

            @test uview(C) === C
            @test typeof(@inferred(uview(C, :, 2:4))) == UnsafeArray{ComplexF32,2}
            @test uview(C, :, 2:4) == view(B, :, 2:4)
        end

        let A = ["foo", "bar", "baz"]
            UnsafeArrays.@gc_preserve A begin
                @test @inferred(uview(A)) === A
                @test typeof(@inferred(uview(A, 2:3))) <: SubArray
                @test uview(A, 2:3) == view(A, 2:3)
            end
        end
    end


    @testset "uviews" begin
        A = rand(Int32, 8)
        B = rand(ComplexF64, 3, 5, 4)

        uviews(() -> 42) == 42
        uviews(A -> typeof(A), A) == UnsafeArray{Int32, 1}
        uviews((A, B) -> (typeof(A), typeof(B)), A, B) == UnsafeArray{Int32, 1}
    end


    @testset "@uviews" begin
        A = rand(Int32, 8)
        B = rand(ComplexF64, 3, 5, 4)

        @uviews(42) == 42
        @uviews(A, typeof(A)) == UnsafeArray{Int32, 1}
        @uviews(A, B, (typeof(A), typeof(B))) == UnsafeArray{Int32, 1}
    end
end
