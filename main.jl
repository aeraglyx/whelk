mutable struct Key
	coords::Tuple{Int64, Int64}
	# finger_efforts::Array{Float64, 1}
end

mutable struct Layout
	# char_map::Array{Char, 2}
	char_map::Dict{Char, Tuple{Int64, Int64}}
	# finger_efforts::Array{Float64, 1}
end




function analyze(dict, corpus_file)
	
	SFB_PENALTY = 4.0::Float64
	INWARD_ROLL = 0.7::Float64
	OUTWARD_ROLL = 1.2::Float64
		
	open(corpus_file, "r") do file
		
		key_prev = false
		same_hand_streak = 0::Int64
		score = 0.0::Float64

		char_count = 0::Int64
		# sfb_count = 0
		# roll_count = 0
		# left_hand_count = 0

		while !eof(file)
			char = lowercase(read(file, Char))
			char_count += 1
			if !haskey(dict, char)
				key_prev = false
				# same_hand_streak += 0.5
				# left_hand_count += 0.5
				continue
			end
			
			key = dict[char]
			
			if key_prev == false
				key_prev = key
				continue
			end

			finger = abs(key[1])::Int64
			finger_prev = abs(key_prev[1])::Int64

			if finger == 1
				stroke_effort = 1.2::Float64
			elseif finger == 2
				stroke_effort = 1.0::Float64
			elseif finger == 3
				stroke_effort = 1.5::Float64
			elseif finger == 4
				stroke_effort = 2.3::Float64
			end

			if key[2] != 0
				stroke_effort *= 1.5
			end

			if sign(key[1]) == sign(key_prev[1])
				stroke_effort *= 1 + same_hand_streak * 0.25
				same_hand_streak += 1

				if finger == finger_prev
					# SFB
					# sfb_count += 1
					stroke_effort *= SFB_PENALTY
				
				elseif finger < finger_prev
					# inward roll
					# roll_streak += 1
					# roll_count += 1
					stroke_effort *= INWARD_ROLL
				elseif finger > finger_prev
					# outward roll
					# roll_streak += 1
					# roll_count += 1
					stroke_effort *= OUTWARD_ROLL
				end

				travel = abs(key[2] - key_prev[2])
				travel = 1 + travel * 0.5
				stroke_effort *= travel
			else
				same_hand_streak = 1
			end
			key_prev = key
			score += stroke_effort
		end
		println(score / char_count)
	end
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

dict = Dict{Char, Tuple{Int64, Int64}}()

for (i, col) in enumerate(eachcol(chars))
	# println(col)
	i = i <= 4 ? i - 5 : i - 4
	for (j, char) in enumerate(col)
		j = 2 - j
		dict[char] = (i, j)
	end
end

# dict['a'], dict['b'] = dict['b'], dict['a']

# print(dict)

# layout = Layout(dict)
# println(a.char_map)

corpus_file = "corpus.txt"
@time analyze(dict, corpus_file)