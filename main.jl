using TOML

include("structs.jl")
include("functions.jl")

function main()
	
	config = "config.toml"
	dict = TOML.parsefile(config)
	settings = (; (Symbol(k) => v for (k,v) in dict)...)
	# println(settings)

	@time optimize_layout(64, 4096, settings)
	# XXX duplicate "you" on line 8474 in "en" has non ascii
end

main()