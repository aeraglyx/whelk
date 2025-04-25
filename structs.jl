struct Offset
	x::Float64
	y::Float64
end

struct Key
	hand::Bool
	finger::Int
	offset::Offset
end

mutable struct Layout
	layout_chars::Vector{Char}
	score::Float64
end