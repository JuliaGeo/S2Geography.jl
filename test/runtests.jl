using Test
using S2Geography
import GeoInterface as GI
import GeoFormatTypes as GFT
using Extents

const S2 = S2Geography

# Reference values on the WGS84 mean sphere (R = 6371008.7714150598 m).
const DEG_M = 111195.10117748393        # one degree of arc, in metres
const BOX_M2 = 1.2364036567076418e10    # area of the 1° × 1° box at the equator

square(x0, y0, w) = Geography("POLYGON (($x0 $y0, $(x0+w) $y0, $(x0+w) $(y0+w), $x0 $(y0+w), $x0 $y0))")

@testset "S2Geography.jl" begin

# ============================================================================
# Construction and serialisation
# ============================================================================

@testset "Construction" begin
    @test Geography("POINT (1 2)") isa Geography

    # WKT -> WKB -> WKT is stable
    for wkt in ("POINT (1.0 2.0)",
                "LINESTRING (0.0 0.0,1.0 1.0,2.0 0.0)",
                "POLYGON ((0.0 0.0,10.0 0.0,10.0 10.0,0.0 10.0,0.0 0.0))",
                "MULTIPOINT (0.0 0.0,1.0 1.0)",
                "MULTILINESTRING ((0.0 0.0,1.0 1.0),(2.0 2.0,3.0 3.0))",
                "GEOMETRYCOLLECTION (POINT (0.0 0.0),LINESTRING (1.0 1.0,2.0 2.0))")
        g = Geography(wkt)
        @test towkt(g) == wkt
        @test towkt(Geography(towkb(g))) == wkt
    end

    # towkb hands back the stored bytes without copying
    g = Geography("POINT (1 2)")
    @test towkb(g) === g.wkb
    @test length(towkb(g)) == 21   # byte order + type + 2 doubles

    # GeoFormatTypes wrappers
    @test towkt(Geography(GFT.WellKnownText(GFT.Geom(), "POINT (3 4)"))) == "POINT (3.0 4.0)"
    @test towkt(Geography(GFT.WellKnownBinary(GFT.Geom(), g.wkb))) == "POINT (1.0 2.0)"
end

@testset "WKT parser" begin
    parse_trait(s) = GI.geomtrait(Geography(s))

    @test parse_trait("POINT (1 2)") == GI.PointTrait()
    @test parse_trait("POINT Z (1 2 3)") == GI.PointTrait()
    @test parse_trait("POINT M (1 2 3)") == GI.PointTrait()
    @test parse_trait("POINT ZM (1 2 3 4)") == GI.PointTrait()

    # Z/M ordinates are dropped: S2 is a two-dimensional spherical model
    z = Geography("POINT Z (1 2 3)")
    @test GI.ncoord(z) == 2
    @test GI.x(z) == 1 && GI.y(z) == 2

    # both MULTIPOINT spellings
    @test GI.ngeom(Geography("MULTIPOINT ((0 0), (1 1))")) == 2
    @test GI.ngeom(Geography("MULTIPOINT (0 0, 1 1)")) == 2

    # EMPTY at every level
    for s in ("POINT EMPTY", "LINESTRING EMPTY", "POLYGON EMPTY",
              "MULTIPOINT EMPTY", "MULTIPOLYGON EMPTY", "GEOMETRYCOLLECTION EMPTY")
        @test Geography(s) isa Geography
    end
    @test GI.ngeom(Geography("LINESTRING EMPTY")) == 0

    # holes
    poly = Geography("POLYGON ((0 0, 3 0, 3 3, 0 3, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))")
    @test GI.ngeom(poly) == 2

    # nested collections — the member split must track parenthesis depth
    gc = Geography("GEOMETRYCOLLECTION (POLYGON ((0 0, 1 0, 1 1, 0 0)), GEOMETRYCOLLECTION (POINT (5 5)))")
    @test GI.geomtrait(gc) == GI.GeometryCollectionTrait()
    @test GI.ngeom(gc) == 2
    @test GI.geomtrait(GI.getgeom(gc, 1)) == GI.PolygonTrait()
    inner = GI.getgeom(gc, 2)
    @test GI.geomtrait(inner) == GI.GeometryCollectionTrait()
    @test GI.x(GI.getgeom(inner, 1)) == 5

    # numeric forms
    @test GI.x(Geography("POINT (-1.5e2 +0.25)")) == -150.0
    @test GI.y(Geography("POINT (-1.5e2 +0.25)")) == 0.25

    # lower case and extra whitespace
    @test GI.geomtrait(Geography("  point  ( 1   2 )  ")) == GI.PointTrait()
end

@testset "WKT parse errors" begin
    for bad in ("POINT", "POINT (1 2", "POINT (1)", "NOTAGEOMETRY (1 2)",
                "POLYGON ((0 0, 1 0, 1 1, 0 0)", "POINT (1 2) trailing")
        @test_throws S2.WKTParseError Geography(bad)
    end

    # the message carries a caret at the offending position
    err = try
        Geography("POINT (1 2")
    catch e
        e
    end
    @test err isa S2.WKTParseError
    @test occursin("^", sprint(showerror, err))
end

# ============================================================================
# GeoInterface
# ============================================================================

@testset "GeoInterface traits" begin
    @test GI.isgeometry(Geography)

    pt = Geography("POINT (1.5 2.5)")
    @test GI.geomtrait(pt) == GI.PointTrait()
    @test GI.ncoord(pt) == 2
    @test !GI.is3d(pt)
    @test !GI.ismeasured(pt)
    @test GI.x(pt) ≈ 1.5
    @test GI.y(pt) ≈ 2.5
    @test GI.getcoord(pt, 1) ≈ 1.5
    @test GI.getcoord(pt, 2) ≈ 2.5

    ls = Geography("LINESTRING (0 0, 1 1, 2 0)")
    @test GI.geomtrait(ls) == GI.LineStringTrait()
    @test GI.ngeom(ls) == 3
    @test GI.x(GI.getgeom(ls, 3)) ≈ 2.0

    poly = Geography("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
    @test GI.geomtrait(poly) == GI.PolygonTrait()
    @test GI.ngeom(poly) == 1
    # WKB does not record the ring/linestring distinction, so rings come back
    # as linestrings -- as they do from every WKB-backed geometry
    ring = GI.getgeom(poly, 1)
    @test GI.geomtrait(ring) == GI.LineStringTrait()
    @test GI.ngeom(ring) == 5

    mp = Geography("MULTIPOINT (0 0, 1 1, 2 2)")
    @test GI.geomtrait(mp) == GI.MultiPointTrait()
    @test GI.ngeom(mp) == 3
    @test GI.y(GI.getgeom(mp, 2)) ≈ 1.0

    mls = Geography("MULTILINESTRING ((0 0, 1 1), (2 2, 3 3))")
    @test GI.geomtrait(mls) == GI.MultiLineStringTrait()
    @test GI.ngeom(mls) == 2
    @test GI.geomtrait(GI.getgeom(mls, 1)) == GI.LineStringTrait()

    mpoly = Geography("MULTIPOLYGON (((0 0, 1 0, 1 1, 0 0)), ((2 2, 3 2, 3 3, 2 2)))")
    @test GI.geomtrait(mpoly) == GI.MultiPolygonTrait()
    @test GI.ngeom(mpoly) == 2

    @test GI.coordinates(poly) == [[[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0], [0.0, 0.0]]]
end

@testset "GeoInterface conversion" begin
    p = GI.Point(1.0, 2.0)
    @test towkt(GI.convert(Geography, p)) == "POINT (1.0 2.0)"
    @test towkt(Geography(p)) == "POINT (1.0 2.0)"

    ls = GI.LineString([(0.0, 0.0), (1.0, 1.0), (2.0, 0.0)])
    @test GI.ngeom(GI.convert(Geography, ls)) == 3

    poly = GI.Polygon([GI.LinearRing([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 0.0)])])
    conv = GI.convert(Geography, poly)
    @test GI.geomtrait(conv) == GI.PolygonTrait()
    @test area(conv) > 0

    # the module name works as a conversion target too
    @test GI.convert(S2Geography, p) isa Geography

    # converting a Geography is the identity
    g = Geography("POINT (3 4)")
    @test GI.convert(Geography, g) === g

    # Geographies survive a round trip through a foreign GeoInterface type
    @test towkt(Geography(GI.Point(GI.x(g), GI.y(g)))) == towkt(g)
end

@testset "Equality and hashing" begin
    a = Geography("POINT (1 2)")
    b = Geography("POINT (1 2)")
    c = Geography("POINT (1 3)")
    @test a == b
    @test a != c
    @test hash(a) == hash(b)
    @test length(Set([a, b, c])) == 2
end

@testset "show" begin
    g = Geography("POINT (1 2)")
    @test occursin("POINT", sprint(show, MIME"text/plain"(), g))
    @test occursin("Geography", sprint(show, g))

    # long geometries are abbreviated rather than dumped in full
    big = Geography("LINESTRING (" * join(("$i $i" for i in 1:400), ", ") * ")")
    @test length(sprint(show, big)) < 400
end

# ============================================================================
# Predicates
# ============================================================================

@testset "Predicates" begin
    outer = square(0, 0, 10)
    overlapping = square(5, 5, 10)
    far = square(20, 20, 10)
    inside = Geography("POINT (5 5)")
    outside = Geography("POINT (15 15)")

    @test contains(outer, inside)
    @test !contains(outer, outside)
    @test within(inside, outer)
    @test !within(outside, outer)

    @test intersects(outer, overlapping)
    @test !intersects(outer, far)
    @test disjoint(outer, far)
    @test !disjoint(outer, overlapping)

    @test equals(outer, square(0, 0, 10))
    @test !equals(outer, far)

    # contains/within are converses
    @test contains(outer, inside) == within(inside, outer)
    # intersects/disjoint are complements
    @test intersects(outer, far) == !disjoint(outer, far)

    # a geography contains itself, and does not lie outside itself
    @test contains(outer, outer)
    @test within(outer, outer)
    @test !disjoint(outer, outer)
end

@testset "dwithin" begin
    a = Geography("POINT (0 0)")
    b = Geography("POINT (1 0)")
    @test dwithin(a, b, DEG_M * 1.01)
    @test !dwithin(a, b, DEG_M * 0.99)
    # dwithin agrees with distance
    @test dwithin(a, b, distance(a, b) * 1.000001)
end

# ============================================================================
# Measures — all in SI metres / square metres
# ============================================================================

@testset "Measures" begin
    unit_box = square(0, 0, 1)

    @test area(unit_box) ≈ BOX_M2 rtol = 1e-9
    @test area(Geography("POINT (0 0)")) == 0
    @test area(Geography("LINESTRING (0 0, 1 0)")) == 0

    @test perimeter(unit_box) ≈ 4 * DEG_M rtol = 1e-3
    @test perimeter(Geography("LINESTRING (0 0, 1 0)")) == 0

    @test arclength(Geography("LINESTRING (0 0, 1 0)")) ≈ DEG_M rtol = 1e-12
    @test arclength(unit_box) == 0   # length is for linear geometries only

    @test distance(Geography("POINT (0 0)"), Geography("POINT (1 0)")) ≈ DEG_M rtol = 1e-12
    @test distance(unit_box, Geography("POINT (0.5 0.5)")) == 0   # inside

    d = Geography("POINT (0 0)")
    far = Geography("POINT (10 0)")
    @test max_distance(d, far) ≈ distance(d, far)
    @test max_distance(unit_box, Geography("POINT (0 0)")) > distance(unit_box, Geography("POINT (0 0)"))

    # antipodal points are half the circumference apart
    @test distance(Geography("POINT (0 0)"), Geography("POINT (180 0)")) ≈ π * S2.EARTH_RADIUS_METERS rtol = 1e-6
end

@testset "Spherical, not planar" begin
    # A geodesic from (-45, 45) to (45, 45) bulges polewards: its bounding box
    # reaches well north of the endpoints, which a planar library would miss.
    bb = GI.extent(Geography("LINESTRING (-45 45, 45 45)"))
    @test bb.X[1] ≈ -45.0
    @test bb.X[2] ≈ 45.0
    @test bb.Y[2] > 54.0
    @test bb.Y[1] ≈ 45.0 atol = 1e-9

    # Its length is shorter than following the parallel would be.
    geodesic = arclength(Geography("LINESTRING (-45 45, 45 45)"))
    along_parallel = 90 * (π / 180) * S2.EARTH_RADIUS_METERS * cosd(45)
    @test geodesic < along_parallel

    # Meridian convergence: a degree of longitude is shorter near the poles.
    equator = distance(Geography("POINT (0 0)"), Geography("POINT (1 0)"))
    high = distance(Geography("POINT (0 60)"), Geography("POINT (1 60)"))
    @test high ≈ equator * cosd(60) rtol = 1e-4

    # Boxes of equal degree extent shrink towards the pole.
    @test area(square(0, 60, 1)) < area(square(0, 0, 1))
end

# ============================================================================
# Constructions
# ============================================================================

@testset "Constructions" begin
    box = square(0, 0, 10)

    c = centroid(box)
    @test GI.geomtrait(c) == GI.PointTrait()
    @test GI.x(c) ≈ 5.0 atol = 0.1
    @test GI.y(c) ≈ 5.0 atol = 0.1

    hull = convex_hull(Geography("MULTIPOINT (0 0, 10 0, 10 10, 0 10, 5 5)"))
    @test GI.geomtrait(hull) == GI.PolygonTrait()
    @test area(hull) ≈ area(box) rtol = 1e-6

    pos = point_on_surface(box)
    @test GI.geomtrait(pos) == GI.PointTrait()
    @test contains(box, pos)

    away = Geography("POINT (20 20)")
    cp = closest_point(box, away)
    @test GI.geomtrait(cp) == GI.PointTrait()
    @test distance(box, away) ≈ distance(cp, away) rtol = 1e-6

    sl = shortest_line(box, away)
    @test GI.geomtrait(sl) == GI.LineStringTrait()
    @test arclength(sl) ≈ distance(box, away) rtol = 1e-6

    ll = longest_line(box, away)
    @test arclength(ll) ≈ max_distance(box, away) rtol = 1e-6
    @test arclength(ll) > arclength(sl)
end

@testset "boundary" begin
    box = square(0, 0, 10)
    b = boundary(box)
    @test GI.geomtrait(b) == GI.MultiLineStringTrait()
    @test arclength(b) ≈ perimeter(box) rtol = 1e-9

    # a polygon with a hole has two boundary rings
    holed = Geography("POLYGON ((0 0, 3 0, 3 3, 0 3, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))")
    @test GI.ngeom(boundary(holed)) == 2

    # the boundary of a line is its endpoints
    endpoints = boundary(Geography("LINESTRING (0 0, 1 0, 2 5)"))
    @test GI.geomtrait(endpoints) == GI.MultiPointTrait()
    @test GI.ngeom(endpoints) == 2
    @test GI.x(GI.getgeom(endpoints, 1)) ≈ 0.0
    @test GI.x(GI.getgeom(endpoints, 2)) ≈ 2.0

    # a closed line has no boundary
    @test GI.ngeom(boundary(Geography("LINESTRING (0 0, 1 0, 1 1, 0 0)"))) == 0

    # points have empty boundaries
    @test GI.geomtrait(boundary(Geography("POINT (1 2)"))) == GI.GeometryCollectionTrait()
    @test GI.ngeom(boundary(Geography("POINT (1 2)"))) == 0

    # boundary is idempotent on the second application for polygons
    @test GI.ngeom(boundary(boundary(box))) == 0
end

@testset "Boolean overlays" begin
    a = square(0, 0, 10)
    b = square(5, 5, 10)

    inter = intersection(a, b)
    uni = union(a, b)
    diff = difference(a, b)
    sym = sym_difference(a, b)

    @test area(inter) > 0
    @test area(inter) < area(a)
    @test area(uni) > area(a)
    @test 0 < area(diff) < area(a)
    @test area(sym) > 0

    # inclusion–exclusion holds on the sphere too
    @test area(uni) ≈ area(a) + area(b) - area(inter) rtol = 1e-9
    @test area(sym) ≈ area(uni) - area(inter) rtol = 1e-9
    @test area(diff) ≈ area(a) - area(inter) rtol = 1e-9

    # `union` on two geographies goes through Base, but Base's set semantics
    # must survive for vectors -- silently overriding them would be a trap
    @test area(union(a, b)) == area(S2.union(a, b))
    @test union([a, b], [b]) == [a, b]                      # Base: set union
    @test S2.union([a, b], [b, a]) isa Vector{<:Geography}  # ours: elementwise
    @test length(S2.union([a, b], [b, a])) == 2

    # disjoint inputs
    far = square(50, 50, 1)
    @test area(intersection(a, far)) == 0
    @test area(union(a, far)) ≈ area(a) + area(far) rtol = 1e-9
    @test area(difference(a, far)) ≈ area(a) rtol = 1e-9
end

# ============================================================================
# Transformations
# ============================================================================

@testset "Transformations" begin
    # simplify drops a vertex that lies within tolerance of the line
    wobbly = Geography("LINESTRING (0 0, 0.5 0.0001, 1 0)")
    @test GI.ngeom(simplify(wobbly, 1000.0)) == 2
    @test GI.ngeom(simplify(wobbly, 1.0)) == 3

    pt = Geography("POINT (0 0)")
    buf = buffer(pt, 10_000.0)
    @test GI.geomtrait(buf) == GI.PolygonTrait()
    @test area(buf) > 0
    @test contains(buf, pt)
    # the buffered disc reaches roughly the requested distance
    @test max_distance(buf, pt) ≈ 10_000.0 rtol = 0.05

    # more quadrant segments means more vertices
    coarse = GI.ngeom(GI.getgeom(buffer(pt, 10_000.0, 2), 1))
    fine = GI.ngeom(GI.getgeom(buffer(pt, 10_000.0, 8), 1))
    @test fine > coarse
    @test GI.ngeom(GI.getgeom(buffer(pt, 10_000.0, "quad_segs=2"), 1)) == coarse

    # segmentize adds vertices without changing the path
    line = Geography("LINESTRING (0 0, 10 0)")
    seg = segmentize(line, 100_000.0)
    @test GI.ngeom(seg) > 2
    @test arclength(seg) ≈ arclength(line) rtol = 1e-6

    # reduce_precision snaps coordinates to a grid measured in degrees
    orig = Geography("POINT (1.123456789 2.123456789)")
    @test GI.x(reduce_precision(orig, 1e-3)) ≈ 1.123 atol = 1e-12
    @test GI.x(reduce_precision(orig, 1e-6)) ≈ 1.123457 atol = 1e-12
    @test GI.y(reduce_precision(orig, 1e-1)) ≈ 2.1 atol = 1e-12
    # coarser than a degree is clamped to a degree
    @test GI.x(reduce_precision(orig, 10.0)) ≈ 1.0 atol = 1e-12

    # tessellating a long geodesic in the plane needs interpolated vertices;
    # doing it on the sphere does not
    long = Geography("LINESTRING (0 0, 90 0)")
    @test GI.ngeom(tessellate_planar(long, 1000.0)) >= 2
    @test GI.ngeom(tessellate(long, 1000.0)) >= 2
end

@testset "Linear referencing" begin
    line = Geography("LINESTRING (0 0, 10 0)")

    @test GI.x(line_interpolate_point(line, 0.0)) ≈ 0.0 atol = 1e-9
    @test GI.x(line_interpolate_point(line, 1.0)) ≈ 10.0 atol = 1e-9
    mid = line_interpolate_point(line, 0.5)
    @test GI.x(mid) ≈ 5.0 atol = 1e-6
    @test GI.y(mid) ≈ 0.0 atol = 1e-9

    @test line_locate_point(line, Geography("POINT (5 0)")) ≈ 0.5 atol = 1e-6
    @test line_locate_point(line, Geography("POINT (0 0)")) ≈ 0.0 atol = 1e-9

    # the two are inverses
    for f in (0.1, 0.25, 0.75)
        @test line_locate_point(line, line_interpolate_point(line, f)) ≈ f atol = 1e-6
    end
end

# ============================================================================
# S2 cells
# ============================================================================

@testset "S2 cells" begin
    pt = Geography("POINT (5 5)")
    id = cellid(pt)
    @test id isa Unsigned
    @test id != 0
    @test cellid(5.0, 5.0) == id
    @test cellid(Geography("POINT (5 6)")) != id

    box = square(0, 0, 10)
    cells = covering(box)
    @test !isempty(cells)
    @test eltype(cells) <: Unsigned

    # a finer minimum level means at least as many cells
    @test length(covering(box, 4)) >= length(covering(box))
    @test length(covering(box, 0, 8)) >= 1
    @test length(covering(box, 0, 12, 4)) <= 4
end

# ============================================================================
# Bounds
# ============================================================================

@testset "Bounds" begin
    box = square(0, 0, 10)
    e = GI.extent(box)
    @test e isa Extents.Extent
    @test e == GI.extent(box)
    # bounds are computed via unit vectors on the sphere, so they carry a few
    # ulp of round-off
    @test e.X[1] ≈ 0.0 atol = 1e-12
    @test e.X[2] ≈ 10.0
    @test e.Y[1] ≈ 0.0 atol = 1e-12
    @test e.Y[2] > 10.0     # the northern edge bows polewards

    pt = GI.extent(Geography("POINT (3 4)"))
    @test pt.X[1] ≈ 3.0 && pt.X[2] ≈ 3.0
    @test pt.Y[1] ≈ 4.0 && pt.Y[2] ≈ 4.0

    # the geometry lies inside its own bounds
    @test Extents.intersects(e, GI.extent(centroid(box)))
end

# ============================================================================
# Batch execution
# ============================================================================

@testset "Batch matches scalar" begin
    polys = [square(0, 0, 10), square(5, 5, 10), square(20, 20, 5)]
    pts = [Geography("POINT ($x $x)") for x in (5.0, 12.0, 22.0)]
    outer = square(0, 0, 10)

    # unary
    @test area(polys) == [area(p) for p in polys]
    @test perimeter(polys) == [perimeter(p) for p in polys]
    @test towkt.(centroid(polys)) == [towkt(centroid(p)) for p in polys]

    # binary, vector against vector
    @test intersects(polys, pts) == [intersects(a, b) for (a, b) in zip(polys, pts)]
    @test distance(polys, pts) == [distance(a, b) for (a, b) in zip(polys, pts)]

    # binary, scalar broadcast against vector
    @test contains(outer, pts) == [contains(outer, p) for p in pts]
    @test within(pts, outer) == [within(p, outer) for p in pts]
    @test distance(outer, pts) ≈ [distance(outer, p) for p in pts]

    # transformations with scalar and vector parameters
    @test towkt.(buffer(pts, 1000.0)) == [towkt(buffer(p, 1000.0)) for p in pts]
    @test towkt.(buffer(pts, [1000.0, 2000.0, 3000.0])) ==
          [towkt(buffer(p, d)) for (p, d) in zip(pts, [1000.0, 2000.0, 3000.0])]

    # results are vectors of the right length even for a single-element input
    @test area([polys[1]]) isa AbstractVector
    @test length(area([polys[1]])) == 1

    # cells
    @test covering(polys) == [covering(p) for p in polys]
    @test cellid(pts) == [cellid(p) for p in pts]

    # boundary
    @test towkt.(boundary(polys)) == [towkt(boundary(p)) for p in polys]
end

@testset "Batch shape errors" begin
    polys = [square(0, 0, 1), square(2, 2, 1)]
    pts = [Geography("POINT (0 0)")]
    @test_throws DimensionMismatch intersects(polys, [pts; pts; pts])
    @test_throws DimensionMismatch buffer(polys, [1.0, 2.0, 3.0])
end

# ============================================================================
# Indexing and introspection
# ============================================================================

@testset "prepare! and memory_used" begin
    box = square(0, 0, 10)
    pt = Geography("POINT (5 5)")

    @test memory_used(box) > 0
    before = memory_used(box)
    @test prepare!(box) === box
    @test memory_used(box) >= before

    # preparing does not change any answer
    @test contains(box, pt)
    @test area(box) ≈ area(square(0, 0, 10))

    # preparing twice is harmless
    @test prepare!(prepare!(box)) === box
end

@testset "Library metadata" begin
    names = S2.kernel_names()
    @test !isempty(names)
    @test "st_area" in names
    @test "st_intersects" in names
end

# ============================================================================
# Lifetime
# ============================================================================

@testset "Handles survive collection" begin
    box = square(0, 0, 10)
    acc = 0.0
    for i in 1:200
        p = Geography("POINT ($(i / 100) $(i / 100))")
        acc += contains(box, p) ? 1.0 : 0.0
        acc += area(square(0, 0, i / 100))
        i % 50 == 0 && GC.gc()
    end
    GC.gc(); GC.gc()
    @test acc > 0
    @test contains(box, Geography("POINT (5 5)"))   # box's handle is still valid
end

end # testset S2Geography.jl
