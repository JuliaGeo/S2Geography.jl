# ============================================================
# GeoInterface.jl implementation for S2Geog
# ============================================================

# ---- Basic trait implementations ----

GeoInterface.isgeometry(::S2Geog) = true

GeoInterface.geomtrait(::S2Geog{Trait}) where Trait = Trait()

GeoInterface.ncoord(::GI.AbstractGeometryTrait, ::S2Geog) = 2
GeoInterface.is3d(::GI.AbstractGeometryTrait, ::S2Geog) = false
GeoInterface.ismeasured(::GI.AbstractGeometryTrait, ::S2Geog) = false

# ============================================================
# WKT-based coordinate/sub-geometry parsing
# ============================================================
#
# The s2geography C API only exposes x/y for single points.
# For all other types (linestrings, polygons, multi-*, collections)
# we parse the WKT to extract coordinates and sub-geometries.
#
# This is the same approach used by the Python s2geography bindings.
# When the C API gains coordinate-iteration functions, these can
# be replaced with direct C calls.

"""
    _parse_coord_sequence(wkt, pos) -> (Vector{NTuple{2,Float64}}, new_pos)

Parse a parenthesized coordinate sequence like `(1 2, 3 4, 5 6)`.
"""
function _parse_coord_sequence(wkt::AbstractString, pos::Int)
    coords = NTuple{2,Float64}[]
    # skip to opening paren
    while pos <= Base.length(wkt) && wkt[pos] != '('
        pos += 1
    end
    pos += 1  # skip '('

    while pos <= Base.length(wkt)
        # skip whitespace/commas
        while pos <= Base.length(wkt) && (wkt[pos] == ' ' || wkt[pos] == ',')
            pos += 1
        end
        if pos > Base.length(wkt) || wkt[pos] == ')'
            pos += 1
            break
        end
        # parse x
        x_start = pos
        while pos <= Base.length(wkt) && wkt[pos] != ' ' && wkt[pos] != ',' && wkt[pos] != ')'
            pos += 1
        end
        x = parse(Float64, SubString(wkt, x_start, pos - 1))
        # skip space
        while pos <= Base.length(wkt) && wkt[pos] == ' '
            pos += 1
        end
        # parse y
        y_start = pos
        while pos <= Base.length(wkt) && wkt[pos] != ' ' && wkt[pos] != ',' && wkt[pos] != ')'
            pos += 1
        end
        y = parse(Float64, SubString(wkt, y_start, pos - 1))
        push!(coords, (x, y))
    end
    return coords, pos
end

"""
    _parse_ring_list(wkt, pos) -> (Vector{Vector{NTuple{2,Float64}}}, new_pos)

Parse a polygon's ring list like `((x y, ...), (x y, ...))`.
"""
function _parse_ring_list(wkt::AbstractString, pos::Int)
    rings = Vector{NTuple{2,Float64}}[]
    # skip to opening paren
    while pos <= Base.length(wkt) && wkt[pos] != '('
        pos += 1
    end
    pos += 1  # skip outer '('

    while pos <= Base.length(wkt)
        while pos <= Base.length(wkt) && (wkt[pos] == ' ' || wkt[pos] == ',')
            pos += 1
        end
        if pos > Base.length(wkt) || wkt[pos] == ')'
            pos += 1
            break
        end
        if wkt[pos] == '('
            ring, pos = _parse_coord_sequence(wkt, pos)
            push!(rings, ring)
        else
            pos += 1
        end
    end
    return rings, pos
end

"""
    _split_multi_wkt(wkt, type_prefix) -> Vector{String}

Split a MULTI* or GEOMETRYCOLLECTION WKT into its component WKT strings.
"""
function _split_multi_wkt(wkt::AbstractString, type_prefix::AbstractString)
    # Find the opening paren after the type keyword
    start = findfirst('(', wkt)
    start === nothing && return String[]

    parts = String[]
    depth = 0
    part_start = start + 1

    # For GEOMETRYCOLLECTION, sub-geometries are full WKT strings separated by commas at depth 1
    # For MULTI*, sub-geometries are parenthesized coord sequences at depth 1
    for i in part_start:Base.length(wkt)
        c = wkt[i]
        if c == '('
            depth += 1
        elseif c == ')'
            depth -= 1
            if depth < 0
                # end of outer parens
                sub = strip(SubString(wkt, part_start, i - 1))
                if !isempty(sub)
                    push!(parts, String(sub))
                end
                break
            end
        elseif c == ',' && depth == 0
            sub = strip(SubString(wkt, part_start, i - 1))
            if !isempty(sub)
                push!(parts, String(sub))
            end
            part_start = i + 1
        end
    end
    return parts
end

# ============================================================
# Lightweight views for sub-geometries (avoids C allocations)
# ============================================================

"""
    S2CoordView

A lightweight view over a coordinate sequence, used for LineString points
and LinearRing points. Implements GeoInterface PointTrait iteration.
"""
struct S2CoordView
    coords::Vector{NTuple{2,Float64}}
end

GeoInterface.isgeometry(::S2CoordView) = true
GeoInterface.geomtrait(::S2CoordView) = GI.LineStringTrait()
GeoInterface.ncoord(::GI.LineStringTrait, v::S2CoordView) = 2
GeoInterface.ngeom(::GI.LineStringTrait, v::S2CoordView) = Base.length(v.coords)
function GeoInterface.getgeom(::GI.LineStringTrait, v::S2CoordView, i::Int)
    S2PointView(v.coords[i])
end

"""
    S2RingView

A lightweight view over a ring's coordinates. Implements LinearRingTrait.
"""
struct S2RingView
    coords::Vector{NTuple{2,Float64}}
end

GeoInterface.isgeometry(::S2RingView) = true
GeoInterface.geomtrait(::S2RingView) = GI.LinearRingTrait()
GeoInterface.ncoord(::GI.LinearRingTrait, v::S2RingView) = 2
GeoInterface.ngeom(::GI.LinearRingTrait, v::S2RingView) = Base.length(v.coords)
function GeoInterface.getgeom(::GI.LinearRingTrait, v::S2RingView, i::Int)
    S2PointView(v.coords[i])
end

"""
    S2PointView

A lightweight view for a single point coordinate.
"""
struct S2PointView
    coord::NTuple{2,Float64}
end

GeoInterface.isgeometry(::S2PointView) = true
GeoInterface.geomtrait(::S2PointView) = GI.PointTrait()
GeoInterface.ncoord(::GI.PointTrait, ::S2PointView) = 2
function GeoInterface.getcoord(::GI.PointTrait, p::S2PointView, i::Int)
    p.coord[i]
end

# ============================================================
# Point
# ============================================================

function GeoInterface.getcoord(::GI.PointTrait, geom::S2Geog{GI.PointTrait}, i::Int)
    out = Ref{Cdouble}()
    if i == 1
        s2geog_x(geom.ptr, out)
    elseif i == 2
        s2geog_y(geom.ptr, out)
    else
        error("S2Geog Point: coordinate index $i out of range (1:2)")
    end
    return out[]
end

# ============================================================
# LineString
# ============================================================

# Cache parsed coordinates per geometry (lazy, on first access)
function _linestring_coords(geom::S2Geog{GI.LineStringTrait})
    wkt = _to_wkt(geom)
    # WKT: LINESTRING (x1 y1, x2 y2, ...)
    coords, _ = _parse_coord_sequence(wkt, 1)
    return coords
end

GeoInterface.ngeom(::GI.LineStringTrait, geom::S2Geog{GI.LineStringTrait}) = Base.length(_linestring_coords(geom))

function GeoInterface.getgeom(::GI.LineStringTrait, geom::S2Geog{GI.LineStringTrait}, i::Int)
    coords = _linestring_coords(geom)
    S2PointView(coords[i])
end

# ============================================================
# Polygon
# ============================================================

function _polygon_rings(geom::S2Geog{GI.PolygonTrait})
    wkt = _to_wkt(geom)
    # WKT: POLYGON ((x1 y1, ...), (x1 y1, ...))
    rings, _ = _parse_ring_list(wkt, 1)
    return rings
end

function GeoInterface.ngeom(::GI.PolygonTrait, geom::S2Geog{GI.PolygonTrait})
    Base.length(_polygon_rings(geom))
end

function GeoInterface.getgeom(::GI.PolygonTrait, geom::S2Geog{GI.PolygonTrait}, i::Int)
    rings = _polygon_rings(geom)
    S2RingView(rings[i])
end

# ============================================================
# MultiPoint
# ============================================================

function _multipoint_coords(geom::S2Geog{GI.MultiPointTrait})
    wkt = _to_wkt(geom)
    # WKT: MULTIPOINT ((0 0), (1 1), (2 2)) — each point is parenthesized
    # Parse by extracting each (x y) pair
    coords = NTuple{2,Float64}[]
    pos = findfirst('(', wkt)
    pos === nothing && return coords
    pos += 1  # skip outer '('
    while pos <= Base.length(wkt)
        while pos <= Base.length(wkt) && (wkt[pos] == ' ' || wkt[pos] == ',')
            pos += 1
        end
        if pos > Base.length(wkt) || wkt[pos] == ')'
            break
        end
        if wkt[pos] == '('
            c, pos = _parse_coord_sequence(wkt, pos)
            append!(coords, c)
        else
            pos += 1
        end
    end
    return coords
end

function GeoInterface.ngeom(::GI.MultiPointTrait, geom::S2Geog{GI.MultiPointTrait})
    Base.length(_multipoint_coords(geom))
end

function GeoInterface.getgeom(::GI.MultiPointTrait, geom::S2Geog{GI.MultiPointTrait}, i::Int)
    coords = _multipoint_coords(geom)
    S2PointView(coords[i])
end

# ============================================================
# MultiLineString
# ============================================================

function _multilinestring_parts(geom::S2Geog{GI.MultiLineStringTrait})
    wkt = _to_wkt(geom)
    # WKT: MULTILINESTRING ((x y, ...), (x y, ...))
    parts = _split_multi_wkt(wkt, "MULTILINESTRING")
    [let (c, _) = _parse_coord_sequence(p, 1); c; end for p in parts]
end

function GeoInterface.ngeom(::GI.MultiLineStringTrait, geom::S2Geog{GI.MultiLineStringTrait})
    Base.length(_multilinestring_parts(geom))
end

function GeoInterface.getgeom(::GI.MultiLineStringTrait, geom::S2Geog{GI.MultiLineStringTrait}, i::Int)
    parts = _multilinestring_parts(geom)
    S2CoordView(parts[i])
end

# ============================================================
# MultiPolygon
# ============================================================

function _multipolygon_parts(geom::S2Geog{GI.MultiPolygonTrait})
    wkt = _to_wkt(geom)
    # WKT: MULTIPOLYGON (((x y, ...), (x y, ...)), ((x y, ...)))
    parts = _split_multi_wkt(wkt, "MULTIPOLYGON")
    [let (r, _) = _parse_ring_list(p, 1); r; end for p in parts]
end

function GeoInterface.ngeom(::GI.MultiPolygonTrait, geom::S2Geog{GI.MultiPolygonTrait})
    Base.length(_multipolygon_parts(geom))
end

"""A lightweight polygon view for MultiPolygon sub-geometries."""
struct S2PolygonView
    rings::Vector{Vector{NTuple{2,Float64}}}
end

GeoInterface.isgeometry(::S2PolygonView) = true
GeoInterface.geomtrait(::S2PolygonView) = GI.PolygonTrait()
GeoInterface.ncoord(::GI.PolygonTrait, ::S2PolygonView) = 2
GeoInterface.ngeom(::GI.PolygonTrait, v::S2PolygonView) = Base.length(v.rings)
function GeoInterface.getgeom(::GI.PolygonTrait, v::S2PolygonView, i::Int)
    S2RingView(v.rings[i])
end

function GeoInterface.getgeom(::GI.MultiPolygonTrait, geom::S2Geog{GI.MultiPolygonTrait}, i::Int)
    parts = _multipolygon_parts(geom)
    S2PolygonView(parts[i])
end

# ============================================================
# GeometryCollection
# ============================================================

function _collection_parts(geom::S2Geog{GI.GeometryCollectionTrait})
    wkt = _to_wkt(geom)
    parts = _split_multi_wkt(wkt, "GEOMETRYCOLLECTION")
    return [_from_wkt(p) for p in parts]
end

function GeoInterface.ngeom(::GI.GeometryCollectionTrait, geom::S2Geog{GI.GeometryCollectionTrait})
    Base.length(_collection_parts(geom))
end

function GeoInterface.getgeom(::GI.GeometryCollectionTrait, geom::S2Geog{GI.GeometryCollectionTrait}, i::Int)
    _collection_parts(geom)[i]
end

# ============================================================
# GeoInterface.convert — convert FROM any GeoInterface geometry TO S2Geog
# ============================================================

# Fallback: convert any geometry to S2Geog by dispatching on its trait
function GeoInterface.convert(::Type{S2Geog}, geom)
    trait = GeoInterface.geomtrait(geom)
    GeoInterface.convert(S2Geog, trait, geom)
end

GeoInterface.convert(::Type{S2Geog}, geom::S2Geog) = geom

function GeoInterface.convert(::Type{S2Geog}, trait::GI.AbstractGeometryTrait, geom)
    GeoInterface.convert(S2Geog{typeof(trait)}, trait, geom)
end

# Point
function GeoInterface.convert(::Type{S2Geog{GI.PointTrait}}, ::GI.PointTrait, geom)
    S2Geog(s2geog_make_point_lnglat(Float64(GI.x(geom)), Float64(GI.y(geom))))
end

# Helper: collect interleaved lng/lat coords from a geometry's points
function _collect_lnglat(trait::GI.AbstractGeometryTrait, geom)
    coords = Float64[]
    for p in GI.getpoint(trait, geom)
        push!(coords, Float64(GI.x(p)))
        push!(coords, Float64(GI.y(p)))
    end
    return coords
end

# MultiPoint
function GeoInterface.convert(::Type{S2Geog{GI.MultiPointTrait}}, trait::GI.MultiPointTrait, geom)
    coords = _collect_lnglat(trait, geom)
    n = div(Base.length(coords), 2)
    S2Geog(s2geog_make_multipoint_lnglat(coords, n))
end

# LineString
function GeoInterface.convert(::Type{S2Geog{GI.LineStringTrait}}, trait::GI.LineStringTrait, geom)
    coords = _collect_lnglat(trait, geom)
    n = div(Base.length(coords), 2)
    S2Geog(s2geog_make_polyline_lnglat(coords, n))
end

# LinearRing → LineString (S2 doesn't have a separate ring type)
function GeoInterface.convert(::Type{S2Geog{GI.LinearRingTrait}}, trait::GI.LinearRingTrait, geom)
    coords = _collect_lnglat(trait, geom)
    n = div(Base.length(coords), 2)
    S2Geog{GI.LineStringTrait}(s2geog_make_polyline_lnglat(coords, n))
end

# Polygon
function GeoInterface.convert(::Type{S2Geog{GI.PolygonTrait}}, ::GI.PolygonTrait, geom)
    nrings = GI.nring(geom)
    ring_sizes = Int64[]
    all_coords = Float64[]
    for i in 1:nrings
        ring = GI.getring(geom, i)
        ring_trait = GI.geomtrait(ring)
        ring_coords = _collect_lnglat(ring_trait, ring)
        push!(ring_sizes, div(Base.length(ring_coords), 2))
        append!(all_coords, ring_coords)
    end
    offsets = Vector{Int64}(undef, nrings + 1)
    offsets[1] = 0
    for i in 1:nrings
        offsets[i + 1] = offsets[i] + ring_sizes[i]
    end
    S2Geog(s2geog_make_polygon_lnglat(all_coords, offsets, nrings))
end

# MultiLineString
function GeoInterface.convert(::Type{S2Geog{GI.MultiLineStringTrait}}, ::GI.MultiLineStringTrait, geom)
    n = GI.ngeom(geom)
    ptrs = Vector{Ptr{S2GeogGeography}}(undef, n)
    for (i, ls) in enumerate(GI.getgeom(geom))
        ls_trait = GI.geomtrait(ls)
        coords = _collect_lnglat(ls_trait, ls)
        npts = div(Base.length(coords), 2)
        ptrs[i] = s2geog_make_polyline_lnglat(coords, npts)
    end
    S2Geog(s2geog_make_collection(ptrs, n))
end

# MultiPolygon
function GeoInterface.convert(::Type{S2Geog{GI.MultiPolygonTrait}}, ::GI.MultiPolygonTrait, geom)
    n = GI.ngeom(geom)
    ptrs = Vector{Ptr{S2GeogGeography}}(undef, n)
    for (i, poly) in enumerate(GI.getgeom(geom))
        nrings = GI.nring(poly)
        ring_sizes = Int64[]
        all_coords = Float64[]
        for j in 1:nrings
            ring = GI.getring(poly, j)
            ring_trait = GI.geomtrait(ring)
            ring_coords = _collect_lnglat(ring_trait, ring)
            push!(ring_sizes, div(Base.length(ring_coords), 2))
            append!(all_coords, ring_coords)
        end
        offsets = Vector{Int64}(undef, nrings + 1)
        offsets[1] = 0
        for j in 1:nrings
            offsets[j + 1] = offsets[j] + ring_sizes[j]
        end
        ptrs[i] = s2geog_make_polygon_lnglat(all_coords, offsets, nrings)
    end
    S2Geog(s2geog_make_collection(ptrs, n))
end

# GeometryCollection
function GeoInterface.convert(::Type{S2Geog{GI.GeometryCollectionTrait}}, ::GI.GeometryCollectionTrait, geom)
    n = GI.ngeom(geom)
    ptrs = Vector{Ptr{S2GeogGeography}}(undef, n)
    for (i, subgeom) in enumerate(GI.getgeom(geom))
        converted = GI.convert(S2Geog, subgeom)
        ptrs[i] = converted.ptr
        # Prevent the finalizer from freeing this pointer — ownership transfers to the collection
        converted.ptr = C_NULL
    end
    S2Geog(s2geog_make_collection(ptrs, n))
end
