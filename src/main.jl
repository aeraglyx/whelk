using Pkg

!("TOML" in keys(Pkg.project().dependencies)) && (Pkg.add("TOML"))
!("HTTP" in keys(Pkg.project().dependencies)) && (Pkg.add("HTTP"))

include("structs.jl")
include("functions.jl")

function main()
	config = get_config("config.toml")
	@time optimize_layout(config)
end

main()
