# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

__precompile__(true)

module UnsafeArrays

using Compat
using Compat: axes

include("util.jl")
include("unsafe_array.jl")
include("uview.jl")

end # module
