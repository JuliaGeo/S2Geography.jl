using S2Geography
using Documenter

DocMeta.setdocmeta!(S2Geography, :DocTestSetup, :(using S2Geography); recursive=true)

makedocs(;
    modules=[S2Geography],
    authors="Anshul Singhvi <anshulsinghvi@gmail.com> and contributors",
    sitename="S2Geography.jl",
    format=Documenter.HTML(;
        canonical="https://JuliaGeo.github.io/S2Geography.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "API Reference" => "api.md",
    ],
    warnonly=true,
)

deploydocs(;
    repo="github.com/JuliaGeo/S2Geography.jl",
    devbranch="main",
)
