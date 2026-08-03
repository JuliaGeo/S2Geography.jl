"""
    EARTH_RADIUS_METERS

The sphere radius s2geography uses to report distances and areas in SI units
(the WGS84 mean radius, ``R_1``).
"""
const EARTH_RADIUS_METERS = 6371008.7714150598

#
# Context: the C API's factory and error objects carry mutable scratch space, so
# a single instance cannot be used from two threads at once. Handle construction
# is short, so one lock-guarded context is simpler than a pool and fast enough.
#
mutable struct Context
    factory::Ptr{CAPI.S2GeogFactory}
    err::ErrorSlot
    lock::ReentrantLock

    function Context()
        ref = Ref{Ptr{CAPI.S2GeogFactory}}(C_NULL)
        code = CAPI.S2GeogFactoryCreate(ref)
        code == CAPI.S2GEOGRAPHY_OK ||
            throw(S2GeographyError(code, "could not create geography factory"))
        ctx = new(ref[], ErrorSlot(), ReentrantLock())
        finalizer(ctx) do c
            c.factory == C_NULL || CAPI.S2GeogFactoryDestroy(c.factory)
            c.factory = C_NULL
            return nothing
        end
        return ctx
    end
end

const CONTEXT = Ref{Context}()

"""
    Geography(wkb::Vector{UInt8})
    Geography(wkt::AbstractString)
    Geography(geom)

A geography on the sphere.

Unlike planar geometry libraries, S2 treats edges as geodesics, so operations
are correct for geographic coordinates without any projection step. Coordinates
are longitude/latitude in degrees.

A `Geography` is backed by its WKB encoding, which is also the interchange
format s2geography itself uses. Constructing one from well-known text, from
well-known binary, or from any [GeoInterface](https://github.com/JuliaGeo/GeoInterface.jl)
geometry are all supported:

```julia
Geography("POLYGON ((0 0, 1 0, 1 1, 0 0))")
Geography(GeoInterface.Point(1.0, 2.0))
```

`Geography` implements the GeoInterface traits, so it can be consumed by any
package in the JuliaGeo ecosystem, and `GeoInterface.convert(Geography, geom)`
brings foreign geometries in.

The underlying S2 object is built lazily on first use and cached; see
[`prepare!`](@ref) to also build the spatial index up front.
"""
mutable struct Geography
    const wkb::Vector{UInt8}
    # Built on demand. `@atomic` so concurrent readers race benignly rather
    # than needing a lock on the hot path.
    @atomic handle::Ptr{CAPI.S2Geog}
end

function Geography(wkb::Vector{UInt8})
    g = Geography(wkb, C_NULL)
    finalizer(_destroy!, g)
    return g
end

Geography(wkb::AbstractVector{UInt8}) = Geography(collect(UInt8, wkb))

function _destroy!(g::Geography)
    h = @atomic g.handle
    h == C_NULL || CAPI.S2GeogDestroy(h)
    @atomic g.handle = C_NULL
    return nothing
end

"""
    handle(g) -> Ptr{CAPI.S2Geog}

The cached S2 object for `g`, constructing it on first use.

The S2 object borrows `g.wkb` rather than copying it, so it is only valid while
`g` is alive -- every caller here reaches it through `g`, which keeps both
alive together.
"""
function handle(g::Geography)
    h = @atomic g.handle
    h == C_NULL || return h

    new_handle = _build_handle(g.wkb)
    old, won = @atomicreplace g.handle C_NULL => new_handle
    if !won
        # Another task got there first; discard ours and use theirs.
        CAPI.S2GeogDestroy(new_handle)
        return old
    end
    return new_handle
end

function _build_handle(wkb::Vector{UInt8})
    ref = Ref{Ptr{CAPI.S2Geog}}(C_NULL)
    code = CAPI.S2GeogCreate(ref)
    code == CAPI.S2GEOGRAPHY_OK || throw(S2GeographyError(code, "could not allocate geography"))
    ptr = ref[]
    ctx = CONTEXT[]
    try
        @lock ctx.lock begin
            GC.@preserve wkb begin
                code = CAPI.S2GeogFactoryInitFromWkbNonOwning(
                    ctx.factory, pointer(wkb), length(wkb), ptr, ctx.err.ptr,
                )
            end
            check(code, ctx.err)
        end
    catch
        CAPI.S2GeogDestroy(ptr)
        rethrow()
    end
    return ptr
end

"""
    prepare!(g) -> g

Build `g`'s spatial index now rather than on first use.

This is seldom a speedup, and is not the knob it looks like:

  - At **32 edges or more**, s2geography builds and caches the index on the
    first predicate call anyway, so `prepare!` only moves that cost earlier.
    Throughput is unchanged.
  - Below **32 edges**, s2geography deliberately answers predicates by brute
    force *as long as no index exists*, because for so few edges that is the
    faster path. Building one disqualifies it, and every later query pays
    roughly 1.5-2x for the privilege.
  - Between about 12 and 31 edges, repeated queries do come out ahead, by some
    1.1-1.25x once the index has paid for itself (a few microseconds, or
    around twenty queries).

So reach for it when you want the index cost to be *deterministic* -- moved out
of a latency-sensitive loop, or off whichever query happens to be first -- and
not as a general optimisation. It also makes [`memory_used`](@ref) report the
indexed footprint.

Preparing twice is free; the index is built once and kept.
"""
function prepare!(g::Geography)
    ctx = CONTEXT[]
    @lock ctx.lock begin
        check(CAPI.S2GeogForcePrepare(handle(g), ctx.err.ptr), ctx.err)
    end
    return g
end

"""
    memory_used(g) -> Int

Total bytes S2 attributes to `g`, including its shape index and coordinate
storage. Only meaningful once the geography has been realised; see
[`prepare!`](@ref).
"""
memory_used(g::Geography) = Int(CAPI.S2GeogMemUsed(handle(g)))

# --- conversions ------------------------------------------------------------

"""
    towkb(g) -> Vector{UInt8}

The well-known binary encoding of `g`. This is the geography's own storage, so
the result is returned without copying; do not mutate it.
"""
towkb(g::Geography) = g.wkb

"""
    towkt(g) -> String

The well-known text encoding of `g`.
"""
towkt(g::Geography) = GFT.val(WellKnownGeometry.getwkt(g))

Base.:(==)(a::Geography, b::Geography) = a.wkb == b.wkb
Base.hash(g::Geography, h::UInt) = hash(g.wkb, hash(:Geography, h))

"""
    _abbrev(wkt, n)

Shorten `wkt` to at most `n` characters. Geometries can hold millions of
vertices, and nobody wants those in a REPL.
"""
_abbrev(wkt::AbstractString, n::Integer) =
    length(wkt) <= n ? wkt : string(first(wkt, max(n - 4, 1)), " ...")

function Base.show(io::IO, ::MIME"text/plain", g::Geography)
    print(io, "Geography ", _abbrev(towkt(g), displaysize(io)[2] - 11))
    return nothing
end

Base.show(io::IO, g::Geography) = print(io, "Geography(", repr(_abbrev(towkt(g), 60)), ")")
