# S2Geography.jl

Julia bindings for [s2geography](https://github.com/paleolimbot/s2geography), providing spherical geometry operations powered by Google's [S2Geometry](https://s2geometry.io/) library.

Unlike planar geometry libraries, S2Geography operates on the sphere, giving correct results for geographic data without projection artifacts.

Implements the [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) interface, so S2Geography geometries work with the broader JuliaGeo ecosystem.

> **Note:** This package currently requires a locally built `libs2geography_c` shared library. A JLL package is in progress.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaGeo/S2Geography.jl")
```

## Quick start

```julia
using S2Geography
import GeoInterface as GI

# Create geometries from WKT
poly = S2Geography._from_wkt("POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))")
point = S2Geography._from_wkt("POINT (5 5)")

# Spatial predicates
S2Geography.contains(poly, point)  # true
S2Geography.intersects(poly, point)  # true

# Distance (in radians; multiply by 6371 for km)
p1 = S2Geography._from_wkt("POINT (0 0)")
p2 = S2Geography._from_wkt("POINT (1 0)")
S2Geography.distance(p1, p2)  # ~0.01745 radians (~1 degree)

# GeoInterface compatible — convert any GI geometry to S2Geog
wrapper_pt = GI.Wrappers.Point(1.0, 2.0)
s2_pt = GI.convert(S2Geog, wrapper_pt)
```

## Available operations

**Predicates:** `intersects`, `equals`, `contains`, `touches`

**Measurements:** `distance`, `area`, `s2_length`, `perimeter`

**Geometry operations:** `centroid`, `convex_hull`, `boundary`

**Boolean operations:** `intersection`, `s2_union`, `difference`, `sym_difference`

## GeoInterface.jl

All `S2Geog` geometries implement GeoInterface traits. You can:
- Query traits: `GI.geomtrait`, `GI.ngeom`, `GI.getgeom`, `GI.ncoord`, `GI.getcoord`
- Convert from any GeoInterface geometry: `GI.convert(S2Geog, geom)`
- Use S2Geog with any package that accepts GeoInterface geometries
