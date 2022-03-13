mutable struct Key
	coords::Vector{Int64}
	# finger_efforts::Array{Float64, 1}
end

mutable struct Layout
	char_map::Array{Char, 2}
	# finger_efforts::Array{Float64, 1}
end




function analyze(layout::Layout, corpus_file)
	open(corpus_file, "r") do file
		while !eof(file)
			char = read(file, Char)
			key = nothing
			# print(char)
			key_prev = key
		end
	end
	# println("something")
end



function print_layout(layout::Layout)
	println("something")
end

function update_layout(layout::Layout)
	println("something")
end

# chars = [['a', 'v'] ['c', 'f']]
# chars = ['a' 'v'; 'c' 'f']

fingers = [
	4 3 2 1 1 2 3 4
	4 3 2 1 1 2 3 4
	4 3 2 1 1 2 3 4
]
chars = [
	'b' 'p' 'l' 'd' 'g' 'f' 'u' 'j'
	's' 't' 'n' 'r' 'a' 'e' 'i' 'o'
	'v' 'm' 'h' 'c' 'z' 'y' 'w' 'k'
]
layout = Layout(chars)
# println(a.char_map)

corpus_file = "corpus_03.txt"
analyze(layout, corpus_file)