# ============================================================
# Spatial predicates — GeoInterface-compatible wrappers
# ============================================================

const S2_PREDICATES = (:intersects, :equals, :contains, :touches)

for jl_funcname in S2_PREDICATES
    c_funcname = Symbol("s2geog_$(jl_funcname)")

    @eval function $jl_funcname(geom1, geom2)::Bool
        $jl_funcname(GI.trait(geom1), geom1, GI.trait(geom2), geom2)
    end

    @eval function $jl_funcname(::GI.AbstractGeometryTrait, geom1, ::GI.AbstractGeometryTrait, geom2)
        g1 = GI.convert(S2Geog, geom1)
        g2 = GI.convert(S2Geog, geom2)
        idx1 = s2geog_shape_index_new(g1.ptr)
        idx2 = s2geog_shape_index_new(g2.ptr)
        out = Ref{Cint}()
        ret = $c_funcname(idx1, idx2, out)
        s2geog_shape_index_destroy(idx2)
        s2geog_shape_index_destroy(idx1)
        ret != 0 && error("S2Geography: $($(QuoteNode(jl_funcname))) failed — $(s2geog_last_error())")
        return out[] != 0
    end
end

# ============================================================
# Distance
# ============================================================

"""
    distance(geom1, geom2) -> Float64

Compute the spherical distance (in radians) between two geometries.
Multiply by Earth's radius (~6371 km) to get distance in km.
"""
function distance(geom1, geom2)
    distance(GI.trait(geom1), geom1, GI.trait(geom2), geom2)
end

function distance(::GI.AbstractGeometryTrait, geom1, ::GI.AbstractGeometryTrait, geom2)
    g1 = GI.convert(S2Geog, geom1)
    g2 = GI.convert(S2Geog, geom2)
    idx1 = s2geog_shape_index_new(g1.ptr)
    idx2 = s2geog_shape_index_new(g2.ptr)
    out = Ref{Cdouble}()
    ret = s2geog_distance(idx1, idx2, out)
    s2geog_shape_index_destroy(idx2)
    s2geog_shape_index_destroy(idx1)
    ret != 0 && error("S2Geography: distance failed — $(s2geog_last_error())")
    return out[]
end

# ============================================================
# Scalar accessors (typed to S2Geog to avoid shadowing Base)
# ============================================================

"""
    area(geom::S2Geog) -> Float64

Compute the area of a geography in steradians.
Multiply by Earth's radius squared (~6371² km²) to get area in km².
"""
function area(geom::S2Geog)
    out = Ref{Cdouble}()
    ret = s2geog_area(geom.ptr, out)
    ret != 0 && error("S2Geography: area failed — $(s2geog_last_error())")
    return out[]
end

"""
    s2_length(geom::S2Geog) -> Float64

Compute the length of a geography in radians (for lines/polylines).
Named `s2_length` to avoid shadowing `Base.length`.
"""
function s2_length(geom::S2Geog)
    out = Ref{Cdouble}()
    ret = s2geog_length(geom.ptr, out)
    ret != 0 && error("S2Geography: length failed — $(s2geog_last_error())")
    return out[]
end

"""
    perimeter(geom::S2Geog) -> Float64

Compute the perimeter of a geography in radians (for polygons).
"""
function perimeter(geom::S2Geog)
    out = Ref{Cdouble}()
    ret = s2geog_perimeter(geom.ptr, out)
    ret != 0 && error("S2Geography: perimeter failed — $(s2geog_last_error())")
    return out[]
end

# ============================================================
# Geometry-returning operations
# ============================================================

"""
    centroid(geom) -> S2Geog{PointTrait}

Compute the centroid of a geography.
"""
function centroid(geom)
    g = GI.convert(S2Geog, geom)
    S2Geog(s2geog_centroid(g.ptr))
end

"""
    convex_hull(geom) -> S2Geog{PolygonTrait}

Compute the convex hull of a geography.
"""
function convex_hull(geom)
    g = GI.convert(S2Geog, geom)
    S2Geog(s2geog_convex_hull(g.ptr))
end

"""
    boundary(geom) -> S2Geog

Compute the boundary of a geography.
"""
function boundary(geom)
    g = GI.convert(S2Geog, geom)
    S2Geog(s2geog_boundary(g.ptr))
end

# ============================================================
# Boolean operations
# ============================================================

for (jl_name, c_name) in (
    (:intersection, :s2geog_intersection),
    (:s2_union, :s2geog_union),
    (:difference, :s2geog_difference),
    (:sym_difference, :s2geog_sym_difference),
)
    @eval function $jl_name(geom1, geom2)
        g1 = GI.convert(S2Geog, geom1)
        g2 = GI.convert(S2Geog, geom2)
        idx1 = s2geog_shape_index_new(g1.ptr)
        idx2 = s2geog_shape_index_new(g2.ptr)
        result_ptr = $c_name(idx1, idx2)
        s2geog_shape_index_destroy(idx2)
        s2geog_shape_index_destroy(idx1)
        S2Geog(result_ptr)
    end
end
