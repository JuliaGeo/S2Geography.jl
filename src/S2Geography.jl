module S2Geography

using CEnum

import GeoInterface as GI
import GeoInterface

# TODO: Replace with S2GeographyC_jll when a JLL package is available
# using S2GeographyC_jll
const libs2geography_c = "libs2geography_c"

include("generated/libs2geography_c_api.jl")
include("types.jl")
include("geointerface.jl")
include("predicates.jl")

export S2Geog

end # module S2Geography
