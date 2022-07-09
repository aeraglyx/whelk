using Pkg

!("TOML" in keys(Pkg.project().dependencies)) && (Pkg.add("TOML"))
!("HTTP" in keys(Pkg.project().dependencies)) && (Pkg.add("HTTP"))

include("structs.jl")
include("functions.jl")

function main()
	settings = get_settings("config.toml")
	@time optimize_layout(settings)
end

main()