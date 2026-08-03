# S2Geography.jl

[![Build Status](https://github.com/JuliaGeo/S2Geography.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaGeo/S2Geography.jl/actions/workflows/CI.yml?query=branch%3Amain)

Julia bindings for [s2geography](https://github.com/paleolimbot/s2geography), a geometry library built on Google's [S2](https://s2geometry.io).

S2 works on the sphere rather than the plane. Edges are geodesics, and predicates and measures are exact for longitude/latitude coordinates without having to pick a projection first — no distortion near the poles, no antimeridian special cases, no dateline-crossing bugs.

Distances and areas are reported in SI **metres** and **square metres** on the WGS84 mean sphere.

Binaries come from [`S2Geography_jll`](https://github.com/JuliaBinaryWrappers/S2Geography_jll.jl), so there is nothing to build.

## Installation

```julia
using Pkg
Pkg.add("S2Geography")
```

## Quick start

```julia
using S2Geography
import GeoInterface as GI

germany = Geography("POLYGON ((5 47, 15 47, 15 55, 5 55, 5 47))")
berlin  = Geography("POINT (13.405 52.52)")
paris   = Geography("POINT (2.3522 48.8566)")

contains(germany, berlin)      # true
area(germany) / 1e6            # 620710.7 km²
distance(berlin, paris) / 1000 # 877.5 km
```

Every operation also accepts vectors and runs them as a single batch:

```julia
cities = Geography.(["POINT (13.4 52.5)", "POINT (2.4 48.9)", "POINT (-74 40.7)"])

contains(germany, cities)   # Bool[1, 0, 0]
distance(germany, cities)   # [0.0, 1.900e5, 5.770e6]
area(buffer(cities, 5000))  # buffer each by 5 km, then measure
```

Mixed scalar and vector arguments broadcast, and each argument may be a vector
in its own right:

```julia
buffer(cities, [1000, 2000, 3000])
```

Batching is worth reaching for. Every scalar call to a measure, construction or
transformation has to renegotiate the underlying kernel's return type, so doing
them one at a time costs about 3.7 µs each; in a batch the negotiation happens
once and the per-element cost drops to about 0.9 µs — roughly **5–7× faster**
for `area`, `centroid`, `distance` and friends. The six boolean predicates are
the exception: they have a dedicated scalar path and are already fast
element-by-element, so batching them is about break-even.

## Constructing geographies

```julia
Geography("POINT (1 2)")                                # WKT
Geography(wkb_bytes)                                    # WKB
Geography(GI.Point(1.0, 2.0))                           # any GeoInterface geometry
GI.convert(Geography, some_geometry)                    # equivalently

towkt(g)   # back to WKT
towkb(g)   # back to WKB (the stored bytes, no copy)
```

WKB is the canonical internal representation, so conversion in either direction
is cheap.

## Operations

**Predicates** — `contains`, `within`, `intersects`, `disjoint`, `equals`, `dwithin`

**Measures** — `area`, `perimeter`, `arclength`, `distance`, `max_distance`

**Constructions** — `centroid`, `convex_hull`, `boundary`, `point_on_surface`, `closest_point`, `shortest_line`, `longest_line`

**Overlays** — `intersection`, `difference`, `sym_difference`, and `union` (see below)

**Transformations** — `simplify`, `buffer`, `reduce_precision`, `segmentize`, `tessellate`, `tessellate_planar`

**Linear referencing** — `line_interpolate_point`, `line_locate_point`

**S2 cells** — `cellid`, `covering`

**Indexing** — `prepare!`, `memory_used`

### A note on `union`

`union(a, b)` works for two geographies, via a method on `Base.union`. It is
deliberately *not* extended to vectors: `union(v1, v2)` on two vectors already
means set union, and quietly redefining that would turn a familiar call into an
elementwise overlay. The batching form is available under its qualified name:

```julia
union(a, b)                 # two geographies
S2Geography.union(as, bs)   # elementwise, in one batch
```

## Spherical, not planar

The difference from a planar library shows up as soon as geometries get large.
A line from 45°W to 45°E along the 45th parallel is a *geodesic*: it bows
polewards, so its bounding box reaches almost 55°N.

```julia
julia> GI.extent(Geography("LINESTRING (-45 45, 45 45)"))
Extent(X = (-45.0, 45.0), Y = (44.99999999999997, 54.7356103172454))
```

Areas shrink towards the poles, as they should:

```julia
julia> area(Geography("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))")) / 1e6      # at the equator
12364.036567076418

julia> area(Geography("POLYGON ((0 60, 1 60, 1 61, 0 61, 0 60))")) / 1e6 # at 60°N
6088.223571303177
```

## GeoInterface.jl

`Geography` implements the [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) traits, so it works with the rest of the JuliaGeo ecosystem:

- Query traits: `GI.geomtrait`, `GI.ngeom`, `GI.getgeom`, `GI.ncoord`, `GI.getcoord`, `GI.x`, `GI.y`
- Bounding boxes: `GI.extent` (computed on the sphere)
- Convert in: `GI.convert(Geography, geom)` or `Geography(geom)`
- Convert out: any GeoInterface consumer can read a `Geography` directly

## Acknowledgements

This package wraps [s2geography](https://github.com/paleolimbot/s2geography) by Dewey Dunnington, which in turn builds on [S2Geometry](https://s2geometry.io) by Google.
