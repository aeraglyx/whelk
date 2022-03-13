mutable struct Layout
	char_map::Array{Char, 2}
	# finger_efforts::Array{Float64, 1}
end



function analyze(layout::Layout, corpus_file)
	open(corpus_file, "r") do file
		while !eof(file)
			char = read(file, Char)
			print(char)
		end
	end
	# println("something")
end



function print_layout(layout::Layout)
	println("something")
end

# chars = [['a', 'v'] ['c', 'f']]
# chars = ['a' 'v'; 'c' 'f']
chars = [
	'b' 'p' 'l' 'd' 'g' 'f' 'u' 'j'
	's' 't' 'n' 'r' 'a' 'e' 'i' 'o'
	'v' 'm' 'h' 'c' 'z' 'y' 'w' 'k'
]
layout = Layout(chars)
# println(a.char_map)

corpus_file = "corpus_03.txt"
analyze(layout, corpus_file)