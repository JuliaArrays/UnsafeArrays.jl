# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

import Test

Test.@testset "Package UnsafeArrays" begin
    include("util.jl")
    include("unsafe_array.jl")
    include("uview.jl")
end
