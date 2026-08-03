"""
    S2GeographyError <: Exception

Raised when a call into the s2geography C library fails.

`code` is the `errno`-compatible status returned by the library (its numeric
value is platform-dependent; only `0`/success is portable) and `msg` is the
detail string the library attached to the failure, if any.
"""
struct S2GeographyError <: Exception
    code::Cint
    msg::String
end

function Base.showerror(io::IO, e::S2GeographyError)
    print(io, "S2GeographyError(", e.code, ")")
    isempty(e.msg) || print(io, ": ", e.msg)
    return nothing
end

"""
    ErrorSlot()

A reusable C error object. The s2geography C API writes failure detail into
one of these, so we keep one per [`Context`](@ref) rather than allocating per
call.
"""
mutable struct ErrorSlot
    ptr::Ptr{CAPI.S2GeogError}

    function ErrorSlot()
        ref = Ref{Ptr{CAPI.S2GeogError}}(C_NULL)
        code = CAPI.S2GeogErrorCreate(ref)
        code == CAPI.S2GEOGRAPHY_OK || throw(S2GeographyError(code, "could not allocate error object"))
        slot = new(ref[])
        finalizer(slot) do s
            s.ptr == C_NULL || CAPI.S2GeogErrorDestroy(s.ptr)
            s.ptr = C_NULL
            return nothing
        end
        return slot
    end
end

Base.unsafe_convert(::Type{Ptr{CAPI.S2GeogError}}, e::ErrorSlot) = e.ptr

"""
    check(code, err) -> nothing

Throw an [`S2GeographyError`](@ref) unless `code` indicates success, using the
message currently held by `err`.
"""
function check(code::Integer, err::ErrorSlot)
    code == CAPI.S2GEOGRAPHY_OK && return nothing
    msg = err.ptr == C_NULL ? "" : CAPI.S2GeogErrorGetMessage(err.ptr)
    throw(S2GeographyError(Cint(code), msg))
end
