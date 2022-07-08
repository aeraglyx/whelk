include("structs.jl")
include("functions.jl")

function main()
	settings = get_settings("config.toml")
	@time optimize_layout(settings)
end

main()