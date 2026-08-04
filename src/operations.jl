#
# The public operation surface.
#
# Two execution paths sit underneath:
#
#   * The six predicates s2geography exposes directly through its C operator
#     interface run through that path, because it lets a geography's shape index
#     be built once (see `prepare!`) and reused across calls.
#   * Everything else runs through the Arrow kernel interface, which is the only
#     way the library exposes the rest of its functionality.
#
# Every operation accepts either a single geography or a vector of them. Vectors
# are executed as one batch, which amortises kernel setup and -- when exactly one
# argument is a scalar -- lets s2geography index that argument once for the whole
# batch.
#

const GeographyOrVector = Union{Geography,AbstractVector{<:Geography}}
const RealOrVector = Union{Real,AbstractVector{<:Real}}
const StringOrVector = Union{AbstractString,AbstractVector{<:AbstractString}}

# --- task-local scratch -----------------------------------------------------
#
# Operator objects accumulate their result internally, so they cannot be shared
# between threads. Keeping them (and an error slot) in task-local storage avoids
# both a lock and repeated construction on the predicate hot path.

mutable struct Op
    ptr::Ptr{CAPI.S2GeogOp}

    function Op(id::Integer)
        ref = Ref{Ptr{CAPI.S2GeogOp}}(C_NULL)
        code = CAPI.S2GeogOpCreate(ref, id)
        code == CAPI.S2GEOGRAPHY_OK ||
            throw(S2GeographyError(code, "s2geography does not support operator id $id"))
        op = new(ref[])
        finalizer(o -> (o.ptr == C_NULL || CAPI.S2GeogOpDestroy(o.ptr); o.ptr = C_NULL; nothing), op)
        return op
    end
end

mutable struct Scratch
    err::ErrorSlot
    ops::Dict{Cint,Op}
end

Scratch() = Scratch(ErrorSlot(), Dict{Cint,Op}())

_scratch() = get!(Scratch, task_local_storage(), :s2geography_scratch)::Scratch
_op(s::Scratch, id::Integer) = get!(() -> Op(id), s.ops, Cint(id))

# --- kernel argument marshalling --------------------------------------------

struct KernelArg
    type::Symbol
    array::Array
    n::Int
    # Whether the caller passed a single value rather than a vector. This is not
    # `n == 1`: a one-element vector is still a vector, and must produce a
    # one-element result rather than a bare scalar.
    scalar::Bool
end

# `:geography` and `:geometry` carry identical WKB; they differ only in the edge
# type declared to GeoArrow, which is how a kernel tells spherical input from
# planar input.
_arg(t::Union{Val{:geography},Val{:geometry}}, g::Geography) =
    KernelArg(_typename(t), binary_array([g.wkb]), 1, true)
_arg(t::Union{Val{:geography},Val{:geometry}}, v::AbstractVector{<:Geography}) =
    KernelArg(_typename(t), binary_array([g.wkb for g in v]), length(v), false)

_typename(::Val{T}) where {T} = T

_arg(::Val{:float64}, x::Real) = KernelArg(:float64, primitive_array([Float64(x)]), 1, true)
_arg(::Val{:float64}, v::AbstractVector{<:Real}) =
    KernelArg(:float64, primitive_array(Float64[x for x in v]), length(v), false)

_arg(::Val{:int32}, x::Real) = KernelArg(:int32, primitive_array([Int32(x)]), 1, true)
_arg(::Val{:int32}, v::AbstractVector{<:Real}) =
    KernelArg(:int32, primitive_array(Int32[x for x in v]), length(v), false)

_arg(::Val{:string}, s::AbstractString) = KernelArg(:string, string_array([s]), 1, true)
_arg(::Val{:string}, v::AbstractVector{<:AbstractString}) =
    KernelArg(:string, string_array(v), length(v), false)

"""
    _call(name, specs...) -> value or vector

Marshal `specs` (each `type => value`), run kernel `name` over them, and return
a scalar when every input was a scalar, or a vector otherwise. Scalars broadcast
against vector arguments, which must all agree in length. Null results become
`missing`.
"""
function _call(name::AbstractString, specs::Pair{Symbol}...)
    args = KernelArg[_arg(Val(t), v) for (t, v) in specs]
    lengths = [a.n for a in args if !a.scalar]
    allequal(lengths) || throw(DimensionMismatch(
        "vector arguments to $name must all have the same length, got $(unique(lengths))"))
    scalar = isempty(lengths)
    nrows = scalar ? 1 : first(lengths)

    result = apply(name, [a.type for a in args], [a.array for a in args], nrows)
    values, valid = result.values, result.valid

    if scalar
        return (valid !== nothing && !valid[1]) ? missing : values[1]
    end
    valid === nothing && return values
    return [v ? x : missing for (v, x) in zip(valid, values)]
end

# --- predicates -------------------------------------------------------------

"""
    _predicate(id, kernel, a, b)

Evaluate a binary predicate: through the C operator interface when both
arguments are single geographies, and through the batch kernel otherwise.
"""
function _predicate(id::Integer, kernel::AbstractString, a::Geography, b::Geography)
    s = _scratch()
    op = _op(s, id)
    check(CAPI.S2GeogOpEvalGeogGeog(op.ptr, handle(a), handle(b), s.err.ptr), s.err)
    return CAPI.S2GeogOpGetInt(op.ptr) != 0
end

_predicate(::Integer, kernel::AbstractString, a::GeographyOrVector, b::GeographyOrVector) =
    _call(kernel, :geography => a, :geography => b)

for (fname, opid, kernel, doc) in (
    (:intersects, CAPI.S2GEOGRAPHY_OP_INTERSECTS, "st_intersects",
     "`a` and `b` share at least one point."),
    (:within, CAPI.S2GEOGRAPHY_OP_WITHIN, "st_within",
     "`a` lies completely within `b`. The converse of [`contains`](@ref)."),
    (:equals, CAPI.S2GEOGRAPHY_OP_EQUALS, "st_equals",
     "`a` and `b` cover the same set of points, regardless of vertex order or representation."),
    (:disjoint, CAPI.S2GEOGRAPHY_OP_DISJOINT, "st_disjoint",
     "`a` and `b` share no points. The negation of [`intersects`](@ref)."),
)
    @eval begin
        """
            $($(string(fname)))(a, b) -> Bool

        Test whether $($doc)

        Either argument may be a vector of geographies, in which case the test is
        evaluated for each row and a `Vector{Bool}` is returned. Mixing a scalar
        with a vector broadcasts the scalar; s2geography indexes it once for the
        whole batch, so `$($(string(fname)))(polygon, points)` is substantially
        faster than a comprehension over `points`.
        """
        $fname(a::GeographyOrVector, b::GeographyOrVector) =
            _predicate($opid, $kernel, a, b)
    end
end

"""
    contains(a, b) -> Bool

Test whether `a` completely contains `b`.

This extends `Base.contains`, so it needs no import. As with the other
predicates, either argument may be a vector; `contains(polygon, points)` indexes
`polygon` once and tests the whole batch against it.
"""
Base.contains(a::Geography, b::Geography) =
    _predicate(CAPI.S2GEOGRAPHY_OP_CONTAINS, "st_contains", a, b)
Base.contains(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_contains", :geography => a, :geography => b)

"""
    dwithin(a, b, distance) -> Bool

Test whether `a` and `b` lie within `distance` metres of each other.

This is cheaper than comparing [`distance`](@ref) against a threshold, because
S2 can stop as soon as the answer is determined.
"""
function dwithin(a::Geography, b::Geography, distance::Real)
    s = _scratch()
    op = _op(s, CAPI.S2GEOGRAPHY_OP_DISTANCE_WITHIN)
    check(CAPI.S2GeogOpEvalGeogGeogDouble(op.ptr, handle(a), handle(b), Float64(distance), s.err.ptr), s.err)
    return CAPI.S2GeogOpGetInt(op.ptr) != 0
end

dwithin(a::GeographyOrVector, b::GeographyOrVector, distance::RealOrVector) =
    _call("st_dwithin", :geography => a, :geography => b, :float64 => distance)

# --- measures ---------------------------------------------------------------

"""
    area(g) -> Float64

The area of `g` in square metres, measured on the sphere. Zero for points and
lines.
"""
area(g::GeographyOrVector) = _call("st_area", :geography => g)

"""
    perimeter(g) -> Float64

The perimeter of `g` in metres: the total length of its polygon boundaries.
Zero for points and lines.
"""
perimeter(g::GeographyOrVector) = _call("st_perimeter", :geography => g)

"""
    arclength(g) -> Float64

The total geodesic length of `g`'s line segments, in metres. Zero for points and
polygons.
"""
arclength(g::GeographyOrVector) = _call("st_length", :geography => g)

"""
    distance(a, b) -> Float64

The shortest geodesic distance between `a` and `b`, in metres. Zero when they
intersect.
"""
distance(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_distance", :geography => a, :geography => b)

"""
    max_distance(a, b) -> Float64

The greatest geodesic distance between any point of `a` and any point of `b`, in
metres.
"""
max_distance(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_maxdistance", :geography => a, :geography => b)

# --- unary constructions ----------------------------------------------------

"""
    centroid(g) -> Geography

The centroid of `g`, as a point.
"""
centroid(g::GeographyOrVector) = _call("st_centroid", :geography => g)

"""
    convex_hull(g) -> Geography

The smallest convex polygon on the sphere containing `g`.
"""
convex_hull(g::GeographyOrVector) = _call("st_convexhull", :geography => g)

"""
    point_on_surface(g) -> Geography

A point guaranteed to lie on `g`. Unlike [`centroid`](@ref), which may fall
outside a concave or multi-part geography, this always returns an interior
point -- useful for placing labels.
"""
point_on_surface(g::GeographyOrVector) = _call("st_pointonsurface", :geography => g)

# --- binary constructions ---------------------------------------------------

"""
    intersection(a, b) -> Geography

The set of points common to `a` and `b`.
"""
intersection(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_intersection", :geography => a, :geography => b)

"""
    S2Geography.union(a, b) -> Geography

The set of points in either `a` or `b`.

Unlike its siblings this one is not exported, and it is deliberately *not* the
same function as `Base.union`. For two vectors `Base.union` already means set
union, and quietly redefining that for vectors of geographies would turn a
familiar call into an elementwise overlay. So the batching form lives here,
under the qualified name, and `Base.union` gains a method only for two single
geographies -- where it cannot be mistaken for anything else.

```julia
union(a, b)                    # two geographies, via Base
S2Geography.union(as, bs)      # elementwise, in one batch
```
"""
union(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_union", :geography => a, :geography => b)

Base.union(a::Geography, b::Geography) = union(a, b)

"""
    difference(a, b) -> Geography

The set of points in `a` but not in `b`.
"""
difference(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_difference", :geography => a, :geography => b)

"""
    sym_difference(a, b) -> Geography

The set of points in exactly one of `a` and `b`.
"""
sym_difference(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_symdifference", :geography => a, :geography => b)

"""
    closest_point(a, b) -> Geography

The point on `a` closest to `b`.
"""
closest_point(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_closestpoint", :geography => a, :geography => b)

"""
    shortest_line(a, b) -> Geography

The two-point line joining the closest points of `a` and `b`. Its
[`arclength`](@ref) equals `distance(a, b)`.
"""
shortest_line(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_shortestline", :geography => a, :geography => b)

"""
    longest_line(a, b) -> Geography

The two-point line joining the farthest points of `a` and `b`. Its
[`arclength`](@ref) equals `max_distance(a, b)`.
"""
longest_line(a::GeographyOrVector, b::GeographyOrVector) =
    _call("st_longestline", :geography => a, :geography => b)

# --- shape transformations --------------------------------------------------

"""
    simplify(g, tolerance) -> Geography

Remove vertices from `g` that deviate from the simplified shape by less than
`tolerance` metres.
"""
simplify(g::GeographyOrVector, tolerance::RealOrVector) =
    _call("st_simplify", :geography => g, :float64 => tolerance)

"""
    buffer(g, distance) -> Geography
    buffer(g, distance, quad_segments::Integer) -> Geography
    buffer(g, distance, params::AbstractString) -> Geography

Expand `g` by `distance` metres (or contract it, when `distance` is negative).

`quad_segments` controls how many segments approximate each quarter turn of a
rounded corner; higher values give a smoother result at the cost of more
vertices. Alternatively `params` accepts a space-separated settings string such
as `"endcap=round quad_segs=8"`, with keys `endcap` (`round`, `flat` or
`butt`), `side` and `quad_segs`.
"""
buffer(g::GeographyOrVector, distance::RealOrVector) =
    _call("st_buffer", :geography => g, :float64 => distance)

buffer(g::GeographyOrVector, distance::RealOrVector, quad_segments::Union{Integer,AbstractVector{<:Integer}}) =
    _call("st_buffer", :geography => g, :float64 => distance, :int32 => quad_segments)

buffer(g::GeographyOrVector, distance::RealOrVector, params::StringOrVector) =
    _call("st_buffer", :geography => g, :float64 => distance, :string => params)

"""
    reduce_precision(g, grid_size) -> Geography

Snap `g`'s coordinates onto a longitude/latitude grid, merging vertices that
collapse together.

`grid_size` is in **degrees**, unlike the other transformations here -- it names
a decimal place rather than a distance. Useful values run from `1` down to
`1e-9`; anything coarser is clamped to `1`, and anything finer to `1e-9`.

```julia
reduce_precision(g, 1e-6)   # round coordinates to six decimal places
```
"""
reduce_precision(g::GeographyOrVector, grid_size::RealOrVector) =
    _call("st_reduceprecision", :geography => g, :float64 => grid_size)

"""
    segmentize(g, max_segment_length) -> Geography

Insert vertices along `g`'s edges so that no segment is longer than
`max_segment_length` metres. The shape is unchanged; the added vertices make it
survive later planar operations, such as plotting, without visible distortion.
"""
segmentize(g::GeographyOrVector, max_segment_length::RealOrVector) =
    _call("st_segmentize", :geography => g, :float64 => max_segment_length)

"""
    tessellate(g, tolerance) -> Geography

Convert `g` from planar to spherical edges, adding vertices until the geodesic
path is within `tolerance` metres of the straight-line path. The inverse of
[`tessellate_planar`](@ref).
"""
tessellate(g::GeographyOrVector, tolerance::RealOrVector) =
    _call("st_tessellategeog", :geometry => g, :float64 => tolerance)

"""
    tessellate_planar(g, tolerance) -> Geography

Convert `g` from spherical to planar edges, adding vertices until the
straight-line path is within `tolerance` metres of the geodesic path. Use this
before handing a geography to a planar tool that would otherwise draw its edges
as straight lines.
"""
tessellate_planar(g::GeographyOrVector, tolerance::RealOrVector) =
    _call("st_tessellategeom", :geography => g, :float64 => tolerance)

# --- linear referencing -----------------------------------------------------

"""
    line_interpolate_point(line, fraction) -> Geography

The point at `fraction` (between 0 and 1) of the way along `line`.
"""
line_interpolate_point(line::GeographyOrVector, fraction::RealOrVector) =
    _call("st_lineinterpolatepoint", :geography => line, :float64 => fraction)

"""
    line_locate_point(line, point) -> Float64

How far along `line` the closest position to `point` lies, as a fraction between
0 and 1. The inverse of [`line_interpolate_point`](@ref).
"""
line_locate_point(line::GeographyOrVector, point::GeographyOrVector) =
    _call("st_linelocatepoint", :geography => line, :geography => point)

# --- S2 cells ---------------------------------------------------------------

"""
    cellid(point) -> UInt64

The S2 cell id of a point geography, at maximum (leaf) precision.
"""
function cellid(point::Geography)
    v = _call("s2_cellidfrompoint", :geography => point)
    return v === missing ? missing : reinterpret(UInt64, v)
end

cellid(points::AbstractVector{<:Geography}) =
    map(v -> v === missing ? missing : reinterpret(UInt64, v),
        _call("s2_cellidfrompoint", :geography => points))

"""
    cellid(lng, lat) -> UInt64

The S2 cell id covering longitude `lng`, latitude `lat` (in degrees).
"""
function cellid(lng::Real, lat::Real)
    v = Ref(CAPI.S2GeogVertex((Float64(lng), Float64(lat), 0.0, 0.0)))
    return CAPI.S2GeogLngLatToCellId(v)
end

"""
    covering(g) -> Vector{UInt64}
    covering(g, min_level) -> Vector{UInt64}
    covering(g, min_level, max_level) -> Vector{UInt64}
    covering(g, min_level, max_level, max_cells) -> Vector{UInt64}

The S2 cell ids of a set of cells that together cover `g`.

Coverings are the standard way to index geographies for search: store the cells
covering each geometry, and a candidate query becomes a set intersection. S2
levels run from 0 (a sixth of the sphere) to 30 (roughly a centimetre);
`max_cells` bounds how many cells may be used, trading tightness for size.
"""
covering(g::GeographyOrVector) =
    _cells(_call("s2_coveringcellids", :geography => g))

covering(g::GeographyOrVector, min_level::Union{Integer,AbstractVector{<:Integer}}) =
    _cells(_call("s2_coveringcellids", :geography => g, :int32 => min_level))

covering(g::GeographyOrVector, min_level::Union{Integer,AbstractVector{<:Integer}},
         max_level::Union{Integer,AbstractVector{<:Integer}}) =
    _cells(_call("s2_coveringcellids", :geography => g, :int32 => min_level, :int32 => max_level))

covering(g::GeographyOrVector, min_level::Union{Integer,AbstractVector{<:Integer}},
         max_level::Union{Integer,AbstractVector{<:Integer}},
         max_cells::Union{Integer,AbstractVector{<:Integer}}) =
    _cells(_call("s2_coveringcellids", :geography => g, :int32 => min_level,
                 :int32 => max_level, :int32 => max_cells))

_cells(v::Vector{Int64}) = reinterpret(UInt64, v)
_cells(v::Missing) = missing
_cells(v::AbstractVector) = map(_cells, v)

# --- boundary ---------------------------------------------------------------
#
# s2geography's C build exposes no boundary kernel, but the operation is purely
# structural -- it does not depend on spherical geometry -- so we derive it from
# the geometry itself.

"""
    boundary(g) -> Geography

The topological boundary of `g`: the rings of a polygon, the endpoints of an
open line, and an empty geometry collection for points.
"""
function boundary(g::Geography)
    io = IOBuffer()
    _boundary!(io, GI.geomtrait(g), g)
    return Geography(take!(io))
end

boundary(v::AbstractVector{<:Geography}) = map(boundary, v)

_empty_collection!(io) = (_write_header!(io, WKB_GEOMETRYCOLLECTION); write(io, UInt32(0)); nothing)

_boundary!(io, ::Union{GI.PointTrait,GI.MultiPointTrait}, g) = _empty_collection!(io)

function _boundary!(io, ::Union{GI.LineStringTrait,GI.LinearRingTrait}, g)
    pts = _endpoints(g)
    _write_header!(io, WKB_MULTIPOINT)
    write(io, UInt32(length(pts)))
    for (x, y) in pts
        _write_header!(io, WKB_POINT)
        _write_point!(io, x, y)
    end
    return nothing
end

function _boundary!(io, ::GI.MultiLineStringTrait, g)
    pts = Tuple{Float64,Float64}[]
    for i in 1:GI.ngeom(g)
        append!(pts, _endpoints(GI.getgeom(g, i)))
    end
    _write_header!(io, WKB_MULTIPOINT)
    write(io, UInt32(length(pts)))
    for (x, y) in pts
        _write_header!(io, WKB_POINT)
        _write_point!(io, x, y)
    end
    return nothing
end

_boundary!(io, ::GI.PolygonTrait, g) = _rings_as_lines!(io, [GI.getgeom(g, i) for i in 1:GI.ngeom(g)])

function _boundary!(io, ::GI.MultiPolygonTrait, g)
    rings = Any[]
    for i in 1:GI.ngeom(g)
        poly = GI.getgeom(g, i)
        append!(rings, [GI.getgeom(poly, j) for j in 1:GI.ngeom(poly)])
    end
    return _rings_as_lines!(io, rings)
end

function _boundary!(io, ::GI.GeometryCollectionTrait, g)
    parts = IOBuffer[]
    for i in 1:GI.ngeom(g)
        child = GI.getgeom(g, i)
        buf = IOBuffer()
        _boundary!(buf, GI.geomtrait(child), child)
        push!(parts, buf)
    end
    _write_header!(io, WKB_GEOMETRYCOLLECTION)
    write(io, UInt32(length(parts)))
    foreach(p -> write(io, take!(p)), parts)
    return nothing
end

function _rings_as_lines!(io, rings)
    _write_header!(io, WKB_MULTILINESTRING)
    write(io, UInt32(length(rings)))
    for ring in rings
        _write_header!(io, WKB_LINESTRING)
        _write_ring!(io, [_xy(GI.getgeom(ring, i)) for i in 1:GI.ngeom(ring)])
    end
    return nothing
end

_xy(p) = (Float64(GI.x(p)), Float64(GI.y(p)))

"""
    _endpoints(line) -> Vector{Tuple{Float64,Float64}}

The boundary points of a line: its two ends, or none when it is closed.
"""
function _endpoints(line)
    n = GI.ngeom(line)
    n == 0 && return Tuple{Float64,Float64}[]
    first_pt = _xy(GI.getgeom(line, 1))
    last_pt = _xy(GI.getgeom(line, n))
    first_pt == last_pt && return Tuple{Float64,Float64}[]
    return [first_pt, last_pt]
end
