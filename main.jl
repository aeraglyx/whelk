using TOML

include("structs.jl")
include("functions.jl")

function main()
	
	config = "config.toml"
	settings = (; TOML.parsefile(config)...)

	@time optimize_layout(64, 4096, settings)
	# XXX duplicate "you" on line 8474 in "en" has non ascii
end

main()