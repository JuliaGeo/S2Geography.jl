#
# A minimal, self-contained implementation of the Arrow C data interface.
#
# s2geography exposes its full operation set only through Apache Sedona's
# scalar-kernel ABI, which speaks Arrow. We need just enough of Arrow to hand
# the library a column of WKB (plus scalar arguments) and read a column back,
# so rather than depending on Arrow.jl we build the handful of structures the
# ABI requires. Nothing here is exported.
#

const ARROW_FLAG_NULLABLE = Int64(2)

mutable struct CArrowSchema
    format::Ptr{Cchar}
    name::Ptr{Cchar}
    metadata::Ptr{Cchar}
    flags::Int64
    n_children::Int64
    children::Ptr{Ptr{CArrowSchema}}
    dictionary::Ptr{CArrowSchema}
    release::Ptr{Cvoid}
    private_data::Ptr{Cvoid}
end

CArrowSchema() = CArrowSchema(C_NULL, C_NULL, C_NULL, 0, 0, C_NULL, C_NULL, C_NULL, C_NULL)

mutable struct CArrowArray
    length::Int64
    null_count::Int64
    offset::Int64
    n_buffers::Int64
    n_children::Int64
    buffers::Ptr{Ptr{Cvoid}}
    children::Ptr{Ptr{CArrowArray}}
    dictionary::Ptr{CArrowArray}
    release::Ptr{Cvoid}
    private_data::Ptr{Cvoid}
end

CArrowArray() = CArrowArray(0, 0, 0, 0, 0, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL)

const SCHEMA_RELEASE_OFFSET = fieldoffset(CArrowSchema, findfirst(==(:release), fieldnames(CArrowSchema)))
const ARRAY_RELEASE_OFFSET = fieldoffset(CArrowArray, findfirst(==(:release), fieldnames(CArrowArray)))

# Structures we hand to the library are backed by Julia-owned memory, so their
# release callbacks only have to mark themselves released.
_release_schema(p::Ptr{Cvoid}) = (unsafe_store!(Ptr{Ptr{Cvoid}}(p + SCHEMA_RELEASE_OFFSET), C_NULL); nothing)
_release_array(p::Ptr{Cvoid}) = (unsafe_store!(Ptr{Ptr{Cvoid}}(p + ARRAY_RELEASE_OFFSET), C_NULL); nothing)

const SCHEMA_RELEASE = Ref(C_NULL)
const ARRAY_RELEASE = Ref(C_NULL)

function _init_release_callbacks!()
    SCHEMA_RELEASE[] = @cfunction(_release_schema, Cvoid, (Ptr{Cvoid},))
    ARRAY_RELEASE[] = @cfunction(_release_array, Cvoid, (Ptr{Cvoid},))
    return nothing
end

"""
    release!(x)

Invoke the release callback of an Arrow structure produced by the library.
"""
function release!(s::CArrowSchema)
    s.release == C_NULL && return nothing
    ccall(s.release, Cvoid, (Ptr{CArrowSchema},), pointer_from_objref(s))
    return nothing
end

function release!(a::CArrowArray)
    a.release == C_NULL && return nothing
    ccall(a.release, Cvoid, (Ptr{CArrowArray},), pointer_from_objref(a))
    return nothing
end

# --- metadata ---------------------------------------------------------------

"""
    metadata_blob(pairs) -> Vector{UInt8}

Encode key/value metadata in the Arrow C data interface's packed format:
an `Int32` pair count followed by length-prefixed keys and values.
"""
function metadata_blob(pairs::Vector{Pair{String,String}})
    io = IOBuffer()
    write(io, Int32(length(pairs)))
    for (k, v) in pairs
        write(io, Int32(ncodeunits(k)))
        write(io, k)
        write(io, Int32(ncodeunits(v)))
        write(io, v)
    end
    return take!(io)
end

"""
    read_metadata(ptr) -> Dict{String,String}

Decode a packed Arrow metadata blob. Returns an empty dictionary for `NULL`.
"""
function read_metadata(ptr::Ptr{Cchar})
    out = Dict{String,String}()
    ptr == C_NULL && return out
    p = Ptr{UInt8}(ptr)
    n = unsafe_load(Ptr{Int32}(p))
    p += 4
    for _ in 1:n
        klen = unsafe_load(Ptr{Int32}(p)); p += 4
        key = unsafe_string(p, klen); p += klen
        vlen = unsafe_load(Ptr{Int32}(p)); p += 4
        val = unsafe_string(p, vlen); p += vlen
        out[key] = val
    end
    return out
end

# --- schemas ----------------------------------------------------------------

"""
    Schema(format; extension=nothing, extension_metadata="")

An `ArrowSchema` whose backing strings are kept alive by the wrapper. These are
immutable descriptions, so the package builds each one it needs exactly once.
"""
struct Schema
    handle::CArrowSchema
    refs::Vector{Any}
end

function Schema(format::AbstractString; extension = nothing, extension_metadata::AbstractString = "")
    refs = Any[]
    fmt = push!(refs, Vector{UInt8}(string(format, '\0')))[end]
    nm = push!(refs, Vector{UInt8}("\0"))[end]
    s = CArrowSchema()
    s.format = pointer(fmt)
    s.name = pointer(nm)
    if extension !== nothing
        md = push!(refs, metadata_blob([
            "ARROW:extension:name" => String(extension),
            "ARROW:extension:metadata" => String(extension_metadata),
        ]))[end]
        s.metadata = pointer(md)
    end
    s.flags = ARROW_FLAG_NULLABLE
    s.release = SCHEMA_RELEASE[]
    push!(refs, s)
    return Schema(s, refs)
end

Base.pointer(s::Schema) = pointer_from_objref(s.handle)

# GeoArrow tags its geometry columns with an extension name plus JSON metadata.
# s2geography only accepts WKB, and only matches a kernel when the declared edge
# type agrees: spherical for geographies, planar for planar geometries.
geoarrow_wkb_schema(edges::AbstractString) =
    Schema("z"; extension = "geoarrow.wkb", extension_metadata = "{\"edges\":\"$edges\"}")

# --- arrays -----------------------------------------------------------------

"""
    Array(...)

An `ArrowArray` together with the Julia buffers it points into. Passing one to
the library is only valid while the wrapper is reachable, which the call sites
guarantee with `GC.@preserve`.
"""
struct Array
    handle::CArrowArray
    refs::Vector{Any}
end

Base.pointer(a::Array) = pointer_from_objref(a.handle)

function _array(len::Integer, buffers::Vector{Ptr{Cvoid}}, refs::Vector{Any})
    push!(refs, buffers)
    a = CArrowArray()
    a.length = len
    a.null_count = 0
    a.offset = 0
    a.n_buffers = length(buffers)
    a.n_children = 0
    a.buffers = pointer(buffers)
    a.release = ARRAY_RELEASE[]
    push!(refs, a)
    return Array(a, refs)
end

"""
    binary_array(values) -> Array

Build a 32-bit-offset Arrow binary array from a vector of byte vectors.
"""
function binary_array(values::AbstractVector{<:AbstractVector{UInt8}})
    total = sum(length, values; init = 0)
    offsets = Vector{Int32}(undef, length(values) + 1)
    data = Vector{UInt8}(undef, total)
    pos = 0
    @inbounds for (i, v) in enumerate(values)
        offsets[i] = Int32(pos)
        copyto!(data, pos + 1, v, 1, length(v))
        pos += length(v)
    end
    offsets[end] = Int32(pos)
    refs = Any[offsets, data]
    return _array(length(values), Ptr{Cvoid}[C_NULL, pointer(offsets), pointer(data)], refs)
end

"""
    string_array(values) -> Array

Build a 32-bit-offset Arrow UTF-8 string array.
"""
string_array(values::AbstractVector{<:AbstractString}) =
    binary_array([codeunits(String(v)) for v in values])

"""
    primitive_array(values) -> Array

Build a fixed-width Arrow array from a vector of bits-type scalars.
"""
function primitive_array(values::Vector{T}) where {T}
    refs = Any[values]
    return _array(length(values), Ptr{Cvoid}[C_NULL, pointer(values)], refs)
end

# --- reading results --------------------------------------------------------

"""
    ArrowArrayView

An immutable, `isbits` mirror of `ArrowArray`, used to read arrays the library
allocated (including nested children, which are reachable only through raw
pointers).
"""
struct ArrowArrayView
    length::Int64
    null_count::Int64
    offset::Int64
    n_buffers::Int64
    n_children::Int64
    buffers::Ptr{Ptr{Cvoid}}
    children::Ptr{Ptr{Cvoid}}
    dictionary::Ptr{Cvoid}
    release::Ptr{Cvoid}
    private_data::Ptr{Cvoid}
end

view(a::CArrowArray) = unsafe_load(Ptr{ArrowArrayView}(pointer_from_objref(a)))
child(a::ArrowArrayView, i::Integer) =
    unsafe_load(Ptr{ArrowArrayView}(unsafe_load(a.children, i)))

_buffers(a::ArrowArrayView) = unsafe_wrap(Base.Array, a.buffers, Int(a.n_buffers))

_getbit(bits, i) = ((bits[(i >> 3) + 1] >> (i & 7)) & 0x01) == 0x01

"""
    validity(a) -> Union{Nothing,Vector{Bool}}

Decode an Arrow validity bitmap, or `nothing` when every slot is valid.
"""
function validity(a::ArrowArrayView)
    a.null_count == 0 && return nothing
    bufs = _buffers(a)
    bufs[1] == C_NULL && return nothing
    n, off = Int(a.length), Int(a.offset)
    bits = unsafe_wrap(Base.Array, Ptr{UInt8}(bufs[1]), cld(n + off, 8))
    return [_getbit(bits, i + off) for i in 0:(n - 1)]
end

"""
    read_primitive(a, T) -> Vector{T}

Copy a fixed-width Arrow buffer into a Julia vector.
"""
function read_primitive(a::ArrowArrayView, ::Type{T}) where {T}
    bufs = _buffers(a)
    return copy(unsafe_wrap(Base.Array, Ptr{T}(bufs[2]) + sizeof(T) * a.offset, Int(a.length)))
end

"""
    read_bools(a) -> Vector{Bool}

Decode an Arrow boolean array, which stores one bit per value.
"""
function read_bools(a::ArrowArrayView)
    bufs = _buffers(a)
    n, off = Int(a.length), Int(a.offset)
    bits = unsafe_wrap(Base.Array, Ptr{UInt8}(bufs[2]), cld(n + off, 8))
    return [_getbit(bits, i + off) for i in 0:(n - 1)]
end

"""
    read_binary(a, format) -> Vector{Vector{UInt8}}

Copy out the elements of an Arrow binary array. `format` selects between 32-bit
(`"z"`) and 64-bit (`"Z"`) offsets.
"""
function read_binary(a::ArrowArrayView, format::AbstractString)
    bufs = _buffers(a)
    O = format == "Z" ? Int64 : Int32
    n = Int(a.length)
    offsets = unsafe_wrap(Base.Array, Ptr{O}(bufs[2]) + sizeof(O) * a.offset, n + 1)
    data = unsafe_wrap(Base.Array, Ptr{UInt8}(bufs[3]), Int(offsets[end]))
    return [data[(offsets[i] + 1):offsets[i + 1]] for i in 1:n]
end

"""
    read_list(a, T) -> Vector{Vector{T}}

Copy out the elements of an Arrow list array with a fixed-width child.
"""
function read_list(a::ArrowArrayView, ::Type{T}) where {T}
    bufs = _buffers(a)
    n = Int(a.length)
    offsets = unsafe_wrap(Base.Array, Ptr{Int32}(bufs[2]) + sizeof(Int32) * a.offset, n + 1)
    c = child(a, 1)
    cbufs = _buffers(c)
    values = unsafe_wrap(Base.Array, Ptr{T}(cbufs[2]) + sizeof(T) * c.offset, Int(c.length))
    return [values[(offsets[i] + 1):offsets[i + 1]] for i in 1:n]
end
