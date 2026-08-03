#
# GeoInterface support.
#
# A Geography stores its WKB, and WellKnownGeometry already provides a lazy,
# spec-compliant GeoInterface implementation over WKB bytes. So rather than
# re-deriving coordinate access from the C API -- which in any case offers no
# way to read coordinates back out -- we forward the traits to that wrapper.
#

"""
    _wkbview(g)

View `g`'s bytes as a GeoInterface-compatible well-known binary geometry.
"""
_wkbview(g::Geography) = GFT.WellKnownBinary(GFT.Geom(), g.wkb)

GI.isgeometry(::Type{Geography}) = true
GI.geomtrait(g::Geography) = GI.geomtrait(_wkbview(g))

GI.ncoord(::GI.AbstractGeometryTrait, ::Geography) = 2
GI.is3d(::GI.AbstractGeometryTrait, ::Geography) = false
GI.ismeasured(::GI.AbstractGeometryTrait, ::Geography) = false

GI.ngeom(t::GI.AbstractGeometryTrait, g::Geography) = GI.ngeom(t, _wkbview(g))
# Note that a polygon's rings come back with `LineStringTrait`, not
# `LinearRingTrait`: WKB has no ring type, so the distinction is not recorded in
# the bytes. This matches how every other WKB-backed geometry in the ecosystem
# behaves, and it is uniform at every nesting depth, which a partial fix here
# would not be.
GI.getgeom(t::GI.AbstractGeometryTrait, g::Geography, i::Integer) = GI.getgeom(t, _wkbview(g), i)

GI.getcoord(t::GI.PointTrait, g::Geography, i::Integer) = GI.getcoord(t, _wkbview(g), i)
GI.x(t::GI.PointTrait, g::Geography) = GI.x(t, _wkbview(g))
GI.y(t::GI.PointTrait, g::Geography) = GI.y(t, _wkbview(g))

# --- construction / conversion ---------------------------------------------

Geography(wkt::AbstractString) = Geography(wkt_to_wkb(wkt))
Geography(wkt::GFT.WellKnownText) = Geography(GFT.val(wkt))
Geography(wkb::GFT.WellKnownBinary) = Geography(GFT.val(wkb))

function Geography(geom)
    GI.isgeometry(geom) || throw(ArgumentError(
        "cannot build a Geography from a $(typeof(geom)); expected well-known text, " *
        "well-known binary, or a GeoInterface geometry"))
    return Geography(GFT.val(WellKnownGeometry.getwkb(geom)))
end

GI.convert(::Type{Geography}, g::Geography) = g
GI.convert(::Type{Geography}, geom) = Geography(geom)
GI.convert(::Type{Geography}, ::GI.AbstractGeometryTrait, geom) = Geography(geom)

"""
    geointerface_geomtype(trait) -> Geography

The hook behind `GeoInterface.convert(S2Geography, geom)`. Every trait maps to
the same type: a `Geography` carries its own geometry kind in its WKB, so this
package needs only the one.
"""
geointerface_geomtype(::GI.AbstractGeometryTrait) = Geography

# --- extent -----------------------------------------------------------------

"""
    GeoInterface.extent(g) -> Extents.Extent

The longitude/latitude bounding rectangle of `g`, in degrees.

S2 computes this on the sphere, so it accounts for the curvature of geodesic
edges: a segment from (0, 0) to (90, 0) bulges away from the parallel joining
its endpoints, and the returned box is tight around the true arc. An empty
geography yields an empty extent.
"""
function GI.extent(g::Geography)
    ctx = CONTEXT[]
    ref = Ref{Ptr{CAPI.S2GeogRectBounder}}(C_NULL)
    code = CAPI.S2GeogRectBounderCreate(ref)
    code == CAPI.S2GEOGRAPHY_OK || throw(S2GeographyError(code, "could not create rect bounder"))
    bounder = ref[]
    try
        @lock ctx.lock begin
            check(CAPI.S2GeogRectBounderBound(bounder, handle(g), ctx.err.ptr), ctx.err)
            if CAPI.S2GeogRectBounderIsEmpty(bounder) != 0
                return Extents.Extent(X = (Inf, -Inf), Y = (Inf, -Inf))
            end
            lo = Ref(CAPI.S2GeogVertex(ntuple(_ -> 0.0, 4)))
            hi = Ref(CAPI.S2GeogVertex(ntuple(_ -> 0.0, 4)))
            check(CAPI.S2GeogRectBounderFinish(bounder, lo, hi, ctx.err.ptr), ctx.err)
            return Extents.Extent(X = (lo[].v[1], hi[].v[1]), Y = (lo[].v[2], hi[].v[2]))
        end
    finally
        CAPI.S2GeogRectBounderDestroy(bounder)
    end
end

Extents.extent(g::Geography) = GI.extent(g)
