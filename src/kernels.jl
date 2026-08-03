#
# Kernel registry.
#
# `S2GeogInitKernels` hands back an array of Sedona scalar-kernel factories --
# one per operation s2geography exposes. Several operations are overloaded
# (`st_buffer` has three arities, `s2_coveringcellids` four), and the ABI's way
# of selecting between them is to call `init` with candidate argument schemas
# and see which factory claims them. We resolve that once per signature and
# cache the answer.
#

struct CSedonaKernel
    function_name::Ptr{Cvoid}
    new_impl::Ptr{Cvoid}
    release::Ptr{Cvoid}
    private_data::Ptr{Cvoid}
end

mutable struct CSedonaKernelImpl
    init::Ptr{Cvoid}
    execute::Ptr{Cvoid}
    get_last_error::Ptr{Cvoid}
    release::Ptr{Cvoid}
    private_data::Ptr{Cvoid}
end

CSedonaKernelImpl() = CSedonaKernelImpl(C_NULL, C_NULL, C_NULL, C_NULL, C_NULL)

# The library requires a buffer of exactly `num_kernels * sizeof(kernel)` bytes.
const KERNELS = CSedonaKernel[]
const KERNEL_INDEX = Dict{String,Vector{Int}}()
const KERNEL_CACHE = Dict{Tuple{String,Vector{Symbol}},Int}()
const KERNEL_LOCK = ReentrantLock()

function _load_kernels!()
    n = Int(CAPI.S2GeogNumKernels())
    resize!(KERNELS, n)
    code = CAPI.S2GeogInitKernels(pointer(KERNELS), sizeof(CSedonaKernel) * n, CAPI.S2GEOGRAPHY_KERNEL_FORMAT_SEDONA_UDF)
    code == CAPI.S2GEOGRAPHY_OK ||
        throw(S2GeographyError(code, "could not initialise s2geography kernels"))
    empty!(KERNEL_INDEX)
    for i in 1:n
        push!(get!(Vector{Int}, KERNEL_INDEX, kernel_name(i)), i)
    end
    return nothing
end

function kernel_name(i::Integer)
    k = KERNELS[i]
    ptr = ccall(k.function_name, Ptr{Cchar}, (Ptr{CSedonaKernel},), pointer(KERNELS, i))
    return ptr == C_NULL ? "" : unsafe_string(ptr)
end

"""
    kernel_names() -> Vector{String}

Names of every scalar kernel the linked s2geography build exposes. Useful for
checking what a given library version supports.
"""
kernel_names() = sort!(collect(keys(KERNEL_INDEX)))

# --- argument types ---------------------------------------------------------
#
# Each kernel argument is described by a symbol naming the Arrow schema to send.

const ARG_SCHEMAS = Dict{Symbol,Schema}()

function _init_arg_schemas!()
    empty!(ARG_SCHEMAS)
    ARG_SCHEMAS[:geography] = geoarrow_wkb_schema("spherical")
    ARG_SCHEMAS[:geometry] = geoarrow_wkb_schema("planar")
    ARG_SCHEMAS[:float64] = Schema("g")
    ARG_SCHEMAS[:int32] = Schema("i")
    ARG_SCHEMAS[:string] = Schema("u")
    return nothing
end

# --- invocation -------------------------------------------------------------

struct KernelImpl
    handle::CSedonaKernelImpl
    index::Int
end

function _new_impl(index::Integer)
    impl = CSedonaKernelImpl()
    ccall(KERNELS[index].new_impl, Cvoid, (Ptr{CSedonaKernel}, Ptr{CSedonaKernelImpl}),
          pointer(KERNELS, index), pointer_from_objref(impl))
    return KernelImpl(impl, Int(index))
end

function _release_impl(impl::KernelImpl)
    h = impl.handle
    h.release == C_NULL && return nothing
    ccall(h.release, Cvoid, (Ptr{CSedonaKernelImpl},), pointer_from_objref(h))
    return nothing
end

function _last_error(impl::KernelImpl)
    h = impl.handle
    h.get_last_error == C_NULL && return ""
    ptr = ccall(h.get_last_error, Ptr{Cchar}, (Ptr{CSedonaKernelImpl},), pointer_from_objref(h))
    return ptr == C_NULL ? "" : unsafe_string(ptr)
end

"""
    _init!(impl, argtypes, out_schema; scalars = C_NULL) -> Bool

Negotiate the return type. Returns `false` when this kernel does not accept the
given argument types, which is how the ABI signals "try another overload".
"""
function _init!(impl::KernelImpl, argtypes::Vector{Symbol}, out::CArrowSchema, scalars::Ptr{Ptr{CArrowArray}})
    schemas = Ptr{CArrowSchema}[pointer(ARG_SCHEMAS[t]) for t in argtypes]
    code = GC.@preserve schemas ccall(
        impl.handle.init, Cint,
        (Ptr{CSedonaKernelImpl}, Ptr{Ptr{CArrowSchema}}, Ptr{Ptr{CArrowArray}}, Int64, Ptr{CArrowSchema}),
        pointer_from_objref(impl.handle), schemas, scalars, length(schemas), pointer_from_objref(out),
    )
    code == 0 || throw(S2GeographyError(code, _last_error(impl)))
    return out.release != C_NULL
end

"""
    resolve(name, argtypes) -> Int

Index of the kernel overload of `name` that accepts `argtypes`. The result is
memoised; a signature the library does not implement raises `ArgumentError`.
"""
function resolve(name::AbstractString, argtypes::Vector{Symbol})
    key = (String(name), argtypes)
    @lock KERNEL_LOCK begin
        cached = get(KERNEL_CACHE, key, 0)
        cached == 0 || return cached
        candidates = get(KERNEL_INDEX, String(name), Int[])
        isempty(candidates) && throw(ArgumentError(
            "s2geography does not provide a kernel named \"$name\"; " *
            "this build exposes: $(join(kernel_names(), ", "))"))
        for i in candidates
            impl = _new_impl(i)
            out = CArrowSchema()
            try
                if _init!(impl, argtypes, out, Ptr{Ptr{CArrowArray}}(C_NULL))
                    release!(out)
                    KERNEL_CACHE[key] = i
                    return i
                end
            finally
                _release_impl(impl)
            end
        end
        throw(ArgumentError(
            "no overload of \"$name\" accepts arguments ($(join(argtypes, ", ")))"))
    end
end

"""
    KernelResult

The Arrow output of a kernel call, decoded into Julia values along with the
validity mask (`nothing` when nothing is null).
"""
struct KernelResult{T}
    values::Vector{T}
    valid::Union{Nothing,Vector{Bool}}
end

"""
    apply(name, argtypes, arrays, nrows) -> KernelResult

Run one batch through a kernel. `arrays` must be parallel to `argtypes`; each is
either length `nrows` or length 1 (a scalar broadcast across the batch).

Length-1 geography arguments are additionally passed to `init` as scalars, which
lets s2geography build a shape index for them once and reuse it for the whole
batch -- the difference between O(n) and O(n log n) work for queries like "which
of these points fall in this polygon".
"""
function apply(name::AbstractString, argtypes::Vector{Symbol}, arrays::Vector{Array}, nrows::Integer)
    length(arrays) == length(argtypes) ||
        throw(ArgumentError("expected $(length(argtypes)) arrays, got $(length(arrays))"))
    index = resolve(name, argtypes)
    impl = _new_impl(index)
    out_schema = CArrowSchema()
    out_array = CArrowArray()
    try
        GC.@preserve arrays begin
            # Offer every length-1 argument as a scalar so the kernel can hoist
            # its preparation out of the row loop.
            scalars = Ptr{CArrowArray}[
                (nrows != 1 && a.handle.length == 1) ? pointer(a) : Ptr{CArrowArray}(C_NULL)
                for a in arrays
            ]
            any_scalar = any(!=(Ptr{CArrowArray}(C_NULL)), scalars)
            applicable = GC.@preserve scalars _init!(
                impl, argtypes, out_schema,
                any_scalar ? pointer(scalars) : Ptr{Ptr{CArrowArray}}(C_NULL),
            )
            applicable || throw(ArgumentError(
                "kernel \"$name\" does not accept arguments ($(join(argtypes, ", ")))"))

            argptrs = Ptr{CArrowArray}[pointer(a) for a in arrays]
            code = GC.@preserve argptrs ccall(
                impl.handle.execute, Cint,
                (Ptr{CSedonaKernelImpl}, Ptr{Ptr{CArrowArray}}, Int64, Int64, Ptr{CArrowArray}),
                pointer_from_objref(impl.handle), argptrs, length(argptrs), nrows,
                pointer_from_objref(out_array),
            )
            code == 0 || throw(S2GeographyError(code, _last_error(impl)))
        end
        return _decode(out_schema, out_array)
    finally
        release!(out_array)
        release!(out_schema)
        _release_impl(impl)
    end
end

"""
    _decode(schema, array) -> KernelResult

Turn a kernel's Arrow output into Julia values, dispatching on the Arrow format
string. Geometry results arrive as WKB and are wrapped as [`Geography`](@ref).
"""
function _decode(schema::CArrowSchema, array::CArrowArray)
    format = unsafe_string(schema.format)
    v = view(array)
    valid = validity(v)
    if format == "g"
        return KernelResult(read_primitive(v, Float64), valid)
    elseif format == "b"
        return KernelResult(read_bools(v), valid)
    elseif format == "l"
        return KernelResult(read_primitive(v, Int64), valid)
    elseif format == "i"
        return KernelResult(read_primitive(v, Int32), valid)
    elseif format == "z" || format == "Z"
        return KernelResult(Geography.(read_binary(v, format)), valid)
    elseif format == "+l"
        return KernelResult(read_list(v, Int64), valid)
    end
    throw(S2GeographyError(Cint(0), "unsupported Arrow output format \"$format\""))
end
