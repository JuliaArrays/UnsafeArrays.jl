# This file is a part of UnsafeArrays.jl, licensed under the MIT License (MIT).

__precompile__(true)

module UnsafeArrays

using Compat
using Compat.Markdown

include("util.jl")
include("dense_unsafe_array.jl")
include("unsafe_array.jl")

end # module
