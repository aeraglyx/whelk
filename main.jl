using TOML

include("structs.jl")
include("functions.jl")

function get_settings(config)
	dict = TOML.parsefile(config)
	settings = (; (Symbol(k) => v for (k,v) in dict)...)
	return settings
end

function main()
	settings = get_settings("config.toml")
	@time optimize_layout(settings)
end

main()