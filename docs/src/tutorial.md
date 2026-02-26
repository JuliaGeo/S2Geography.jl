# Tutorial

This tutorial shows how to use S2Geography.jl with real-world geographic data
from [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl).

## Loading data

```@example tutorial
using S2Geography
import GeoInterface as GI
using NaturalEarth

countries = naturalearth("admin_0_countries", 110)
nothing # hide
```

Pick out two countries by name:

```@example tutorial
names = countries.NAME
germany_idx = findfirst(==("Germany"), names)
france_idx = findfirst(==("France"), names)

germany_geom = countries.geometry[germany_idx]
france_geom = countries.geometry[france_idx]
nothing # hide
```

## Converting to S2Geog

Any GeoInterface-compatible geometry can be converted to `S2Geog`:

```@example tutorial
germany = GI.convert(S2Geog, germany_geom)
france = GI.convert(S2Geog, france_geom)
```

## Spatial predicates

Test whether two countries share a border:

```@example tutorial
S2Geography.intersects(germany, france)
```

```@example tutorial
brazil_idx = findfirst(==("Brazil"), names)
brazil = GI.convert(S2Geog, countries.geometry[brazil_idx])
S2Geography.intersects(germany, brazil)
```

Check if a point is inside a country:

```@example tutorial
berlin = S2Geography._from_wkt("POINT (13.405 52.52)")
S2Geography.contains(germany, berlin)
```

## Measurements

Distance between two points (in radians -- multiply by 6371 for km):

```@example tutorial
paris = S2Geography._from_wkt("POINT (2.3522 48.8566)")
d = S2Geography.distance(berlin, paris)
km = d * 6371
println("Berlin to Paris: $(round(km, digits=1)) km")
```

Area (in steradians -- multiply by 6371^2 for km^2):

```@example tutorial
a = S2Geography.area(germany)
km2 = a * 6371^2
println("Germany area: $(round(km2, digits=0)) km²")
```

## Boolean operations

Compute the intersection of two countries (their shared border region):

```@example tutorial
overlap = S2Geography.intersection(germany, france)
println("Intersection area: $(round(S2Geography.area(overlap) * 6371^2, digits=0)) km²")
```

Compute the centroid:

```@example tutorial
c = S2Geography.centroid(germany)
println("Germany centroid: ($(round(GI.x(c), digits=2))°, $(round(GI.y(c), digits=2))°)")
```
