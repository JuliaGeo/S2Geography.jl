# ============================================================
# Geography kind enum (from s2geography C++ GeographyKind)
# ============================================================

# The C API returns these from s2geog_geography_kind
const GEOG_KIND_POINT = 1               # PointGeography (single or multi)
const GEOG_KIND_POLYLINE = 2            # PolylineGeography (single or multi)
const GEOG_KIND_POLYGON = 3            # PolygonGeography
const GEOG_KIND_GEOGRAPHY_COLLECTION = 4 # GeographyCollection

"""
Determine the GeoInterface trait by examining the WKT prefix,
since s2geography uses a flat kind enum (POINT covers multipoint, etc.)
"""
function _detect_trait_from_wkt(wkt::AbstractString)
    # Check WKT prefix to distinguish multi-types
    if startswith(wkt, "GEOMETRYCOLLECTION")
        GI.GeometryCollectionTrait
    elseif startswith(wkt, "MULTIPOLYGON")
        GI.MultiPolygonTrait
    elseif startswith(wkt, "MULTILINESTRING")
        GI.MultiLineStringTrait
    elseif startswith(wkt, "MULTIPOINT")
        GI.MultiPointTrait
    elseif startswith(wkt, "POLYGON")
        GI.PolygonTrait
    elseif startswith(wkt, "LINESTRING")
        GI.LineStringTrait
    elseif startswith(wkt, "POINT")
        GI.PointTrait
    else
        error("Unknown WKT type prefix in: $(first(wkt, 30))")
    end
end

function _geog_kind_to_trait(kind::Integer, ptr::Ptr{S2GeogGeography})
    if kind == GEOG_KIND_POINT
        # PointGeography stores multiple points as a single shape.
        # Distinguish via num_points.
        npts = Ref{Cint}(0)
        s2geog_num_points(ptr, npts)
        npts[] > 1 ? GI.MultiPointTrait : GI.PointTrait
    elseif kind == GEOG_KIND_POLYLINE
        n = s2geog_geography_num_shapes(ptr)
        n > 1 ? GI.MultiLineStringTrait : GI.LineStringTrait
    elseif kind == GEOG_KIND_POLYGON
        GI.PolygonTrait
    elseif kind == GEOG_KIND_GEOGRAPHY_COLLECTION
        # Could be a typed multi or a generic collection — inspect WKT
        writer = _get_wkt_writer()
        wkt_ptr = s2geog_wkt_writer_write(writer, ptr)
        wkt = unsafe_string(wkt_ptr)
        s2geog_string_free(wkt_ptr)
        _detect_trait_from_wkt(wkt)
    else
        error("Unknown S2Geography kind $kind")
    end
end

# ============================================================
# Thread-local WKT reader/writer cache
# ============================================================

const _wkt_reader_cache = Dict{UInt, Ptr{S2GeogWKTReader}}()
const _wkt_writer_cache = Dict{UInt, Ptr{S2GeogWKTWriter}}()
const _wkt_reader_lock = ReentrantLock()
const _wkt_writer_lock = ReentrantLock()

function _get_wkt_reader()
    tid = Threads.threadid()
    lock(_wkt_reader_lock) do
        get!(_wkt_reader_cache, tid) do
            s2geog_wkt_reader_new()
        end
    end
end

function _get_wkt_writer()
    tid = Threads.threadid()
    lock(_wkt_writer_lock) do
        get!(_wkt_writer_cache, tid) do
            s2geog_wkt_writer_new(16)
        end
    end
end

# ============================================================
# S2Geog: the main wrapper type
# ============================================================

"""
    S2Geog{Trait}

A wrapper around an `S2GeogGeography` pointer. Parameterized by GeoInterface
geometry trait for type-stable dispatch.

Automatically frees the underlying C object via a finalizer.
"""
mutable struct S2Geog{Trait}
    ptr::Ptr{S2GeogGeography}

    function S2Geog{Trait}(ptr::Ptr{S2GeogGeography}) where Trait <: GI.AbstractGeometryTrait
        ptr == C_NULL && error("S2Geography: received NULL pointer (check s2geog_last_error())")
        geom = new{Trait}(ptr)
        finalizer(geom) do g
            if g.ptr != C_NULL
                s2geog_geography_destroy(g.ptr)
            end
        end
        return geom
    end

    function S2Geog(ptr::Ptr{S2GeogGeography})
        ptr == C_NULL && error("S2Geography: received NULL pointer — $(s2geog_last_error())")
        kind = s2geog_geography_kind(ptr)
        trait = _geog_kind_to_trait(kind, ptr)
        geom = new{trait}(ptr)
        finalizer(geom) do g
            if g.ptr != C_NULL
                s2geog_geography_destroy(g.ptr)
            end
        end
        return geom
    end
end

# ============================================================
# WKT helpers
# ============================================================

function _to_wkt(geog::S2Geog)
    writer = _get_wkt_writer()
    wkt_ptr = s2geog_wkt_writer_write(writer, geog.ptr)
    wkt_ptr == C_NULL && error("S2Geography: WKT write failed — $(s2geog_last_error())")
    wkt = unsafe_string(wkt_ptr)
    s2geog_string_free(wkt_ptr)
    return wkt
end

function _from_wkt(wkt::AbstractString)
    reader = _get_wkt_reader()
    ptr = s2geog_wkt_reader_read(reader, wkt, -1)
    return S2Geog(ptr)
end

# ============================================================
# Pretty printing
# ============================================================

function Base.show(io::IO, ::MIME"text/plain", geom::S2Geog{Trait}) where Trait
    print(io, "S2Geog{$(nameof(Trait))} ")
    wkt = _to_wkt(geom)
    if Base.length(wkt) > 80
        print(io, wkt[1:77], "...")
    else
        print(io, wkt)
    end
end

function Base.show(io::IO, geom::S2Geog{Trait}) where Trait
    print(io, "S2Geog{$(nameof(Trait))}(…)")
end
