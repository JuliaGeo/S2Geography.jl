# Tutorial

This tutorial works through S2Geography.jl using real country boundaries from
[NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl).

## Loading data

```@example tutorial
using S2Geography
import GeoInterface as GI
using NaturalEarth

countries = naturalearth("admin_0_countries", 110)
nothing # hide
```

Pick out a few countries by name:

```@example tutorial
names = countries.NAME
idx(name) = findfirst(==(name), names)

germany = Geography(countries.geometry[idx("Germany")])
france  = Geography(countries.geometry[idx("France")])
brazil  = Geography(countries.geometry[idx("Brazil")])
nothing # hide
```

`Geography` accepts any GeoInterface-compatible geometry. `GI.convert(Geography,
geom)` does the same thing, and WKT and WKB work too:

```@example tutorial
berlin = Geography("POINT (13.405 52.52)")
paris  = Geography("POINT (2.3522 48.8566)")
nothing # hide
```

## Spatial predicates

Do Germany and France share a border?

```@example tutorial
intersects(germany, france)
```

```@example tutorial
intersects(germany, brazil)
```

Is Berlin in Germany?

```@example tutorial
contains(germany, berlin)
```

`within` is the converse of `contains`, and `disjoint` the complement of
`intersects`:

```@example tutorial
within(berlin, germany), disjoint(germany, brazil)
```

## Measurements

All measures are in SI units: metres for lengths, square metres for areas. No
conversion factor is needed.

```@example tutorial
d = distance(berlin, paris)
println("Berlin to Paris: $(round(d / 1000, digits=1)) km")
```

```@example tutorial
a = area(germany)
println("Germany: $(round(a / 1e6, digits=0)) km²")
```

`distance` measures the shortest separation between two geographies, so a point
inside a polygon is zero metres away from it:

```@example tutorial
distance(germany, berlin)
```

The perimeter of Germany's boundary, and the great-circle distance between its
two furthest-apart points:

```@example tutorial
println("Perimeter: $(round(perimeter(germany) / 1000, digits=0)) km")
println("Furthest:  $(round(max_distance(germany, germany) / 1000, digits=0)) km")
```

## Working in batches

Every operation accepts vectors as well as single geographies, and evaluates
them in one pass through the underlying library. Scalar arguments broadcast
against vector ones.

```@example tutorial
all_countries = Geography.(countries.geometry)
areas = area(all_countries)
nothing # hide
```

```@example tutorial
order = sortperm(areas; rev=true)
[names[i] => round(areas[i] / 1e6, digits=0) for i in order[1:5]]
```

Which countries does a point in the North Sea fall closest to?

```@example tutorial
buoy = Geography("POINT (3.0 56.0)")
d = distance(all_countries, buoy)
[names[i] => round(d[i] / 1000, digits=1) for i in sortperm(d)[1:5]]
```

Batching is what makes this practical — one call over 177 countries rather than
177 separate calls.

## Boolean operations

```@example tutorial
shared = intersection(germany, france)
println("Shared border region: $(round(area(shared) / 1e6, digits=2)) km²")
```

```@example tutorial
both = union(germany, france)
round(area(both) / 1e6, digits=0)
```

Areas obey inclusion–exclusion, on the sphere just as in the plane:

```@example tutorial
area(union(germany, france)) ≈
    area(germany) + area(france) - area(intersection(germany, france))
```

## Derived geometries

```@example tutorial
c = centroid(germany)
println("Centroid: ($(round(GI.x(c), digits=2))°, $(round(GI.y(c), digits=2))°)")
```

`point_on_surface` is guaranteed to lie inside the geometry, which a centroid is
not:

```@example tutorial
contains(germany, point_on_surface(germany))
```

`boundary` returns the outline as lines, and `convex_hull` the smallest convex
region containing the input:

```@example tutorial
outline = boundary(germany)
GI.geomtrait(outline), arclength(outline) ≈ perimeter(germany)
```

```@example tutorial
hull = convex_hull(germany)
round(area(hull) / area(germany), digits=3)   # how far from convex Germany is
```

## Transformations

`simplify` removes vertices that lie within a tolerance (in metres) of the
simplified path:

```@example tutorial
coarse = simplify(germany, 10_000)   # 10 km tolerance
println("Simplified area is within $(round(100 * abs(area(coarse) / area(germany) - 1), digits=2))% of the original")
```

`buffer` grows a geometry by a distance in metres:

```@example tutorial
grown = buffer(berlin, 50_000)      # 50 km disc around Berlin
round(area(grown) / 1e6, digits=0)  # ≈ π × 50²
```

`segmentize` densifies long edges so they can be drawn as straight lines in a
projected plot without visibly departing from the true geodesic:

```@example tutorial
long_edge = Geography("LINESTRING (-100 40, 20 50)")
GI.ngeom(long_edge), GI.ngeom(segmentize(long_edge, 100_000))
```

## Linear referencing

```@example tutorial
route = Geography("LINESTRING (2.3522 48.8566, 13.405 52.52)")
halfway = line_interpolate_point(route, 0.5)
println("Halfway: ($(round(GI.x(halfway), digits=3))°, $(round(GI.y(halfway), digits=3))°)")
```

```@example tutorial
line_locate_point(route, halfway)
```

## Bounding boxes

`GeoInterface.extent` computes the bounding box **on the sphere**, so it accounts
for the curvature of geodesic edges. A line along the 45th parallel bulges
polewards, and the box reflects that:

```@example tutorial
GI.extent(Geography("LINESTRING (-45 45, 45 45)"))
```

A planar library would report `Y = (45.0, 45.0)` here, which is wrong: the
shortest path between those endpoints genuinely passes north of 54°.

```@example tutorial
GI.extent(germany)
```

## S2 cells

S2 covers the sphere with a hierarchy of cells. `cellid` gives the leaf cell
containing a point, and `covering` gives a set of cells that together contain a
geometry — the basis for spatial indexing and joins.

```@example tutorial
cellid(berlin)
```

```@example tutorial
cells = covering(germany)
length(cells)
```

```@example tutorial
covering(germany, 0, 8, 4)   # min level 0, max level 8, at most 4 cells
```

## Preparing geometries for repeated queries

`prepare!` builds S2's spatial index for a geography up front, rather than
letting it be constructed on demand.

```@example tutorial
prepare!(germany)
memory_used(germany)
```
