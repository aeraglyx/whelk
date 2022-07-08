struct Key
	hand::Bool
	finger::Int
	row::Int
end

mutable struct Layout
	layout_chars::Vector{Char}
	score::Float64
end