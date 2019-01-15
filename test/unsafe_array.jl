# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

using UnsafeArrays
using Compat
using Compat.Test
using Compat.Random
using Compat: axes


@testset "unsafe_array" begin
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


    function test_A_UA(test_code::Function, ::Type{T}, Val_N::Val{N}) where {T, N}
        A = rand_array(T, Val_N)
        UA = UnsafeArray(pointer(A), size(A))
        UnsafeArrays.@gc_preserve A test_code(A, UA)
    end


    @testset "ctors" begin
        test_A(Float64, Val(0)) do A
            ptr = pointer(A)
            sz = size(A)
            @test typeof(@inferred(UnsafeArray{Float64,0}(Val(true), ptr, sz))) == UnsafeArray{Float64,0}
            @test typeof(@inferred(UnsafeArray{Float64,0}(ptr, sz))) == UnsafeArray{Float64,0}
            @test typeof(@inferred(UnsafeArray(ptr, sz))) == UnsafeArray{Float64,0}
            @test_throws MethodError typeof(UnsafeArray{Float64,0}(Val(false), ptr, sz))
        end

        test_A(Int, Val(2)) do A
            ptr = pointer(A)
            sz = size(A)
            @test typeof(@inferred(UnsafeArray{Int,2}(Val(true), ptr, sz))) == UnsafeArray{Int,2}
            @test typeof(@inferred(UnsafeArray{Int,2}(ptr, sz))) == UnsafeArray{Int,2}
            @test typeof(@inferred(UnsafeArray(ptr, sz))) == UnsafeArray{Int,2}
            @test_throws MethodError typeof(UnsafeArray{Int,2}(Val(false), ptr, sz))
        end
    end


    @testset "size, length, index style, etc." begin
        run_test(T::Type, Val_N::Val) = test_A_UA(T, Val_N) do A, UA
            T = eltype(UA)
            @test @inferred(length(UA)) == length(A)
            @test @inferred(IndexStyle(UA)) == IndexLinear()
            @test @inferred(LinearIndices(UA)) == LinearIndices(A)
            @test @inferred(eachindex(UA)) == eachindex(A)

            @test @inferred(Base.unsafe_convert(Ptr{T}, UA)) == Base.unsafe_convert(Ptr{T}, A)
            @test @inferred(pointer(UA)) == pointer(A)

            @test @inferred(Base.iscontiguous(UA)) == true
            @test @inferred(Base.iscontiguous(typeof(UA))) == true
        end

        run_test(Int, Val(0))
        run_test(Float64, Val(2))
    end


    @testset "equality, getindex and setindex!" begin
        test_A_UA(Float32, Val(2)) do A, UA
            test_A_UA(Float32, Val(2)) do B, UB
                @test UA != UB
                A .= B
                @test UA == UB
            end
        end

        test_A_UA(Float32, Val(2)) do A, UA
            B = rand_array(Float32, Val(2))
            rand!(B)
            for i in eachindex(UA, B)
                UA[i] = B[i]
            end
            @test A == B
            @test UA == B
            @test all(i -> UA[i] == B[i], eachindex(UA, B))
            @test all(i -> UA[i] == B[i], CartesianIndices(size(UA)))
        end

        test_A_UA(Int, Val(1)) do A, UA
            @test all(x -> x == 42, @inferred fill!(UA, 42))
        end
    end


    @testset "view" begin
        test_A_UA(Int16, Val(0)) do A, UA
            @test view(UA) === UA
            @test view(UA) == view(A)
        end

        test_A_UA(Int, Val(1)) do A, UA
            @test typeof(@inferred(view(UA, :))) == UnsafeArray{Int,1}
            @test typeof(@inferred(view(UA, 2:4))) == UnsafeArray{Int,1}
            @test typeof(@inferred(view(UA, 2))) == UnsafeArray{Int,0}

            @test view(UA, :) == view(A, :)
            @test view(UA, 2:4) == view(A, 2:4)
            @test view(UA, 2) == view(A, 2)

            @test isbits(view(UA, :)) == true
            @test isbits(view(UA, 2:4)) == true
            @test isbits(view(UA, 2)) == true
        end

        test_A_UA(Float32, Val(3)) do A, UA
            @test typeof(@inferred(view(UA, :))) == UnsafeArray{Float32,1}
            @test typeof(@inferred(view(UA, :, :, :))) == UnsafeArray{Float32,3}
            # TODO: Type inference fails for some reason:
            # @test typeof(@inferred(view(UA, :, 3, :))) <: SubArray
            @test typeof((view(UA, :, 3, :))) <: SubArray
            @test typeof(@inferred(view(UA, :, :, 3))) == UnsafeArray{Float32,2}
            @test typeof(@inferred(view(UA, :, 2:4, 3))) == UnsafeArray{Float32,2}
            @test typeof(@inferred(view(UA, :, 2, 3))) == UnsafeArray{Float32,1}
            @test typeof(@inferred(view(UA, 2, 2, 3))) == UnsafeArray{Float32,0}
            @test_throws BoundsError view(UA, 2, 2:20, 3)

            @test view(UA, :) == view(A, :)
            @test view(UA, :, :, :) == view(A, :, :, :)
            @test view(UA, :, 3, :) == view(A, :, 3, :)
            @test view(UA, :, :, 3) == view(A, :, :, 3)
            @test view(UA, :, 2:4, 3) == view(A, :, 2:4, 3)
            @test view(UA, :, 2, 3) == view(A, :, 2, 3)
            @test view(UA, 2, 2, 3) == view(A, 2, 2, 3)

            @test isbits(view(UA, :)) == true
            @test isbits(view(UA, :, :, :)) == true
            @test isbits(view(UA, :, 3, :)) == true
        end
    end


    @testset "reshape" begin
        test_A_UA(Float32, Val(3)) do A, UA
            @test typeof(@inferred(reshape(UA, size(UA, 1), size(UA, 2) * size(UA, 3)))) == UnsafeArray{Float32, 2}
            @test typeof(@inferred(reshape(UA, size(UA, 1) * size(UA, 2) * size(UA, 3)))) == UnsafeArray{Float32, 1}

            @test reshape(UA, size(UA, 1), size(UA, 2) * size(UA, 3)) == reshape(A, size(A, 1), size(A, 2) * size(A, 3))
            @test reshape(UA, size(UA, 1) * size(UA, 2) * size(UA, 3)) == reshape(A, size(A, 1) * size(A, 2) * size(A, 3))
        end

        test_A_UA(Int, Val(1)) do A, UA
            @test typeof(@inferred(reshape(UA, 2, div(size(UA, 1), 2)))) == UnsafeArray{Int, 2}
            @test reshape(UA, 2, div(size(UA, 1), 2)) == reshape(A, 2, div(size(A, 1), 2))
        end
    end


    @testset "copyto! and conversion" begin
        test_A_UA(Int32, Val(3)) do A, UA
            B = similar(A, Int32)
            @test B === @inferred(copyto!(B, UA))
            @test B == A
        end

        test_A_UA(Int32, Val(3)) do A, UA
            B = similar(A, Int64)
            @test B === @inferred(copyto!(B, UA))
            @test B == A
        end

        test_A_UA(Int32, Val(3)) do A, UA
            B = zeros(Int32, size(A)...)
            @test B === @inferred(copyto!(B, 3, UA, 5, 7))
            C = zeros(Int32, size(A)...)
            copyto!(C, 3, A, 5, 7)
            @test B == C
        end

        test_A_UA(Int32, Val(3)) do A, UA
            B = zeros(Int64, size(A)...)
            @test B === @inferred(copyto!(B, 3, UA, 5, 7))
            C = zeros(Int64, size(A)...)
            copyto!(C, 3, A, 5, 7)
            @test B == C
        end

        test_A_UA(Int32, Val(1)) do A, UA
            B = zeros(Int32, size(A)...)
            @test B === @inferred(copyto!(B, 2, UA, 3, 4))
            C = zeros(Int32, size(A)...)
            copyto!(C, 2, A, 3, 4)
            @test B == C
            @test_throws BoundsError copyto!(B, 3, UA, 5, 7)
        end

        test_A_UA(Int32, Val(1)) do A, UA
            B = zeros(Int64, size(A)...)
            @test B === @inferred(copyto!(B, 2, UA, 3, 4))
            C = zeros(Int32, size(A)...)
            copyto!(C, 2, A, 3, 4)
            @test B == C
            @test_throws BoundsError copyto!(B, 3, UA, 5, 7)
        end


        test_A_UA(Float64, Val(3)) do A, UA
            B = rand(Float64, size(A)...)
            A2 = deepcopy(A)
            copyto!(A2, B)
            @test UA === @inferred(copyto!(UA, B))
            @test UA == A2
        end

        test_A_UA(Float64, Val(3)) do A, UA
            B = rand(Float32, size(A)...)
            A2 = deepcopy(A)
            copyto!(A2, B)
            @test UA === @inferred(copyto!(UA, B))
            @test UA == A2
        end

        test_A_UA(Float64, Val(3)) do A, UA
            B = rand(Float64, size(A)...)
            A2 = deepcopy(A)
            copyto!(A2, 3, B, 5, 7)
            @test UA === @inferred(copyto!(UA, 3, B, 5, 7))
            @test UA == A2
        end

        test_A_UA(Float64, Val(3)) do A, UA
            B = rand(Float32, size(A)...)
            A2 = deepcopy(A)
            copyto!(A2, 3, B, 5, 7)
            @test UA === @inferred(copyto!(UA, 3, B, 5, 7))
            @test UA == A2
        end

        test_A_UA(Float64, Val(1)) do A, UA
            B = rand(Float64, size(A)...)
            A2 = deepcopy(A)
            copyto!(A2, 2, B, 3, 4)
            @test UA === @inferred(copyto!(UA, 2, B, 3, 4))
            @test UA == A2
            @test_throws BoundsError copyto!(UA, 3, B, 5, 7)
        end

        test_A_UA(Float64, Val(1)) do A, UA
            B = rand(Float32, size(A)...)
            A2 = deepcopy(A)
            copyto!(A2, 2, B, 3, 4)
            @test UA === @inferred(copyto!(UA, 2, B, 3, 4))
            @test UA == A2
            @test_throws BoundsError copyto!(UA, 3, B, 5, 7)
       end
    end


    @testset "deepcopy" begin
        test_A_UA(Float32, Val(3)) do A, UA
            @test typeof(@inferred(deepcopy(UA))) == typeof(A)
            @test deepcopy(UA) == A
        end

        test_A_UA(Int16, Val(1)) do A, UA
            @test typeof(@inferred(deepcopy(UA))) == typeof(A)
            @test deepcopy(UA) == A
        end
    end


    # # Disabled, as specialization of Base.unaliascopy is disabled:
    #
    # @testset "unaliascopy" begin
    #     test_A_UA(Float32, Val(3)) do A, UA
    #         @test typeof(@inferred(Base.unaliascopy(UA))) == typeof(A)
    #         @test Base.unaliascopy(UA) == A
    #     end
    #
    #     test_A_UA(Int16, Val(1)) do A, UA
    #         @test typeof(@inferred(Base.unaliascopy(UA))) == typeof(A)
    #         @test Base.unaliascopy(UA) == A
    #     end
    # end


    @testset "conversion" begin
        test_A_UA(Float32, Val(3)) do A, UA
            @test typeof(@inferred(convert(Array, UA))) == typeof(A)
            @test convert(Array, UA) == A
        end

        test_A_UA(Int16, Val(1)) do A, UA
            @test typeof(@inferred(convert(Array, UA))) == typeof(A)
            @test convert(Array, UA) == A
        end
    end
end
