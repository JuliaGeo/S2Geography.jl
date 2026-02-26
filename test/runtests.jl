using Test
using S2Geography
import GeoInterface as GI

const S2 = S2Geography

@testset "S2Geography.jl" begin

    # ============================================================
    # WKT round-trip & basic construction
    # ============================================================
    @testset "WKT round-trip" begin
        for wkt in (
            "POINT (1 2)",
            "LINESTRING (0 0, 1 1, 2 0)",
            "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))",
            "MULTIPOINT ((0 0), (1 1), (2 2))",
            "MULTILINESTRING ((0 0, 1 1), (2 2, 3 3))",
            "GEOMETRYCOLLECTION (POINT (0 0), LINESTRING (1 1, 2 2))",
        )
            geog = S2._from_wkt(wkt)
            @test geog isa S2.S2Geog
            wkt2 = S2._to_wkt(geog)
            @test !isempty(wkt2)
        end
    end

    # ============================================================
    # GeoInterface: Point
    # ============================================================
    @testset "GeoInterface — Point" begin
        pt = S2._from_wkt("POINT (1.5 2.5)")
        @test GI.geomtrait(pt) == GI.PointTrait()
        @test GI.ncoord(pt) == 2
        @test GI.is3d(pt) == false
        @test GI.ismeasured(pt) == false
        @test GI.x(pt) ≈ 1.5
        @test GI.y(pt) ≈ 2.5
        @test GI.getcoord(pt, 1) ≈ 1.5
        @test GI.getcoord(pt, 2) ≈ 2.5
    end

    # ============================================================
    # GeoInterface: LineString
    # ============================================================
    @testset "GeoInterface — LineString" begin
        ls = S2._from_wkt("LINESTRING (0 0, 1 1, 2 0)")
        @test GI.geomtrait(ls) == GI.LineStringTrait()
        @test GI.ngeom(ls) == 3
        p1 = GI.getgeom(ls, 1)
        @test GI.x(p1) ≈ 0.0
        @test GI.y(p1) ≈ 0.0
        p3 = GI.getgeom(ls, 3)
        @test GI.x(p3) ≈ 2.0
        @test GI.y(p3) ≈ 0.0
    end

    # ============================================================
    # GeoInterface: Polygon
    # ============================================================
    @testset "GeoInterface — Polygon" begin
        poly = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        @test GI.geomtrait(poly) == GI.PolygonTrait()
        @test GI.ngeom(poly) == 1  # one ring
        ring = GI.getgeom(poly, 1)
        @test GI.geomtrait(ring) == GI.LinearRingTrait()
        @test GI.ngeom(ring) == 5  # 5 vertices (closed)
    end

    @testset "GeoInterface — Polygon with hole" begin
        poly = S2._from_wkt("POLYGON ((0 0, 20 0, 20 20, 0 20, 0 0), (5 5, 15 5, 15 15, 5 15, 5 5))")
        @test GI.ngeom(poly) == 2  # exterior + 1 hole
        exterior = GI.getgeom(poly, 1)
        hole = GI.getgeom(poly, 2)
        @test GI.ngeom(exterior) == 5
        @test GI.ngeom(hole) == 5
    end

    # ============================================================
    # GeoInterface: MultiPoint
    # ============================================================
    @testset "GeoInterface — MultiPoint" begin
        mp = S2._from_wkt("MULTIPOINT ((0 0), (1 1), (2 2))")
        @test GI.geomtrait(mp) == GI.MultiPointTrait()
        @test GI.ngeom(mp) == 3
        p2 = GI.getgeom(mp, 2)
        @test GI.x(p2) ≈ 1.0
        @test GI.y(p2) ≈ 1.0
    end

    # ============================================================
    # GeoInterface: MultiLineString
    # ============================================================
    @testset "GeoInterface — MultiLineString" begin
        mls = S2._from_wkt("MULTILINESTRING ((0 0, 1 1), (2 2, 3 3))")
        @test GI.geomtrait(mls) == GI.MultiLineStringTrait()
        @test GI.ngeom(mls) == 2
        ls1 = GI.getgeom(mls, 1)
        @test GI.geomtrait(ls1) == GI.LineStringTrait()
        @test GI.ngeom(ls1) == 2
    end

    # ============================================================
    # GeoInterface: GeometryCollection
    # ============================================================
    @testset "GeoInterface — GeometryCollection" begin
        gc = S2._from_wkt("GEOMETRYCOLLECTION (POINT (0 0), LINESTRING (1 1, 2 2))")
        @test GI.geomtrait(gc) == GI.GeometryCollectionTrait()
        @test GI.ngeom(gc) == 2
        pt = GI.getgeom(gc, 1)
        @test GI.geomtrait(pt) == GI.PointTrait()
        ls = GI.getgeom(gc, 2)
        @test GI.geomtrait(ls) == GI.LineStringTrait()
    end

    # ============================================================
    # GeoInterface.convert — from GI.Wrappers to S2Geog
    # ============================================================
    @testset "GI.convert" begin
        @testset "Point" begin
            p = GI.Wrappers.Point(1.0, 2.0)
            s = GI.convert(S2.S2Geog, p)
            @test GI.geomtrait(s) == GI.PointTrait()
            @test GI.x(s) ≈ 1.0
            @test GI.y(s) ≈ 2.0
        end

        @testset "LineString" begin
            ls = GI.Wrappers.LineString([(0.0, 0.0), (1.0, 1.0), (2.0, 0.0)])
            s = GI.convert(S2.S2Geog, ls)
            @test GI.geomtrait(s) == GI.LineStringTrait()
            @test GI.ngeom(s) == 3
        end

        @testset "Polygon" begin
            ring = GI.Wrappers.LinearRing([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0), (0.0, 0.0)])
            poly = GI.Wrappers.Polygon([ring])
            s = GI.convert(S2.S2Geog, poly)
            @test GI.geomtrait(s) == GI.PolygonTrait()
            @test GI.ngeom(s) == 1
        end

        @testset "MultiPoint" begin
            mp = GI.Wrappers.MultiPoint([(0.0, 0.0), (1.0, 1.0)])
            s = GI.convert(S2.S2Geog, mp)
            @test GI.geomtrait(s) == GI.MultiPointTrait()
            @test GI.ngeom(s) == 2
        end

        @testset "identity" begin
            pt = S2._from_wkt("POINT (3 4)")
            @test GI.convert(S2.S2Geog, pt) === pt
        end
    end

    # ============================================================
    # Predicates
    # ============================================================
    @testset "Predicates" begin
        poly1 = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        poly2 = S2._from_wkt("POLYGON ((5 5, 15 5, 15 15, 5 15, 5 5))")
        poly3 = S2._from_wkt("POLYGON ((20 20, 30 20, 30 30, 20 30, 20 20))")

        @test S2.intersects(poly1, poly2) == true
        @test S2.intersects(poly1, poly3) == false

        @test S2.contains(poly1, S2._from_wkt("POINT (5 5)")) == true
        @test S2.contains(poly1, S2._from_wkt("POINT (15 15)")) == false

        pt = S2._from_wkt("POINT (1 2)")
        pt2 = S2._from_wkt("POINT (1 2)")
        @test S2.equals(pt, pt2) == true
    end

    # ============================================================
    # Distance
    # ============================================================
    @testset "Distance" begin
        p1 = S2._from_wkt("POINT (0 0)")
        p2 = S2._from_wkt("POINT (1 0)")
        d = S2.distance(p1, p2)
        @test d > 0.0
        # 1 degree ≈ 0.01745 radians
        @test isapprox(d, deg2rad(1.0), atol=0.001)
    end

    # ============================================================
    # Scalar accessors
    # ============================================================
    @testset "Area" begin
        poly = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        a = S2.area(poly)
        @test a > 0.0
    end

    @testset "Length" begin
        ls = S2._from_wkt("LINESTRING (0 0, 1 0)")
        l = S2.s2_length(ls)
        @test l > 0.0
        @test isapprox(l, deg2rad(1.0), atol=0.001)
    end

    @testset "Perimeter" begin
        poly = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        p = S2.perimeter(poly)
        @test p > 0.0
    end

    # ============================================================
    # Geometry operations
    # ============================================================
    @testset "Centroid" begin
        poly = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        c = S2.centroid(poly)
        @test GI.geomtrait(c) == GI.PointTrait()
        @test isapprox(GI.x(c), 5.0, atol=0.1)
        @test isapprox(GI.y(c), 5.0, atol=0.1)
    end

    @testset "Convex hull" begin
        mp = S2._from_wkt("MULTIPOINT ((0 0), (10 0), (10 10), (0 10), (5 5))")
        ch = S2.convex_hull(mp)
        @test GI.geomtrait(ch) == GI.PolygonTrait()
        @test S2.area(ch) > 0.0
    end

    @testset "Boundary" begin
        poly = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        b = S2.boundary(poly)
        @test b isa S2.S2Geog
    end

    # ============================================================
    # Boolean operations
    # ============================================================
    @testset "Boolean operations" begin
        poly1 = S2._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
        poly2 = S2._from_wkt("POLYGON ((5 5, 15 5, 15 15, 5 15, 5 5))")

        inter = S2.intersection(poly1, poly2)
        @test inter isa S2.S2Geog
        @test S2.area(inter) > 0.0

        uni = S2.s2_union(poly1, poly2)
        @test uni isa S2.S2Geog
        @test S2.area(uni) > S2.area(poly1)

        diff = S2.difference(poly1, poly2)
        @test diff isa S2.S2Geog
        @test S2.area(diff) > 0.0
        @test S2.area(diff) < S2.area(poly1)

        symdiff = S2.sym_difference(poly1, poly2)
        @test symdiff isa S2.S2Geog
        @test S2.area(symdiff) > 0.0
    end

    # ============================================================
    # Show methods
    # ============================================================
    @testset "Show" begin
        pt = S2._from_wkt("POINT (1 2)")
        buf = IOBuffer()
        show(buf, MIME("text/plain"), pt)
        s = String(take!(buf))
        @test occursin("S2Geog{PointTrait}", s)
        @test occursin("POINT", s)

        buf = IOBuffer()
        show(buf, pt)
        s = String(take!(buf))
        @test occursin("S2Geog{PointTrait}", s)
    end

end
