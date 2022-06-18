struct Key
	hand::Bool
	finger::Int
	row::Int
	# TODO base effort
end

mutable struct Layout
	layout_chars::Vector{Char}
	score::Float64
	finger_load::Vector{Float64}
end