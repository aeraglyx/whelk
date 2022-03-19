mutable struct Key
	# coords::Tuple{Int64, Int64}
	hand  ::Bool
	finger::Int
	row   ::Int
end

mutable struct Layout
	# char_map::Array{Char, 2}
	char_map::Dict{Char, Tuple{Int64, Int64}}
	# finger_efforts::Array{Float64, 1}
end



const SFB_PENALTY  = 4.0::Float64
const INWARD_ROLL  = 0.7::Float64
const OUTWARD_ROLL = 1.2::Float64

function analyze(dict, corpus_file)
	
		
	open(corpus_file, "r") do file
		
		key_prev = false
		same_hand_streak::Int64 = 0
		score::Float64 = 0.0

		char_count::Int64 = 0
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

			# finger = abs(key[1])::Int64

			stroke_effort::Float64 = 0.0

			if key.finger == 1
				stroke_effort = 1.2
			elseif key.finger == 2
				stroke_effort = 1.0
			elseif key.finger == 3
				stroke_effort = 1.5
			elseif key.finger == 4
				stroke_effort = 2.3
			end

			if key.row != 2
				@fastmath stroke_effort *= 1.5
			end

			if key.hand == key_prev.hand
				@fastmath stroke_effort *= 1 + same_hand_streak * 0.25
				same_hand_streak += 1

				if key.finger == key_prev.finger
					# SFB
					# @fastmath sfb_count += 1
					@fastmath stroke_effort *= SFB_PENALTY
				
				elseif key.finger < key_prev.finger
					# inward roll
					# @fastmath roll_streak += 1
					# @fastmath roll_count += 1
					@fastmath stroke_effort *= INWARD_ROLL
				elseif key.finger > key_prev.finger
					# outward roll
					# @fastmath roll_streak += 1
					# @fastmath roll_count += 1
					@fastmath stroke_effort *= OUTWARD_ROLL
				end

				# @fastmath travel = key.row - key_prev.row
				@fastmath travel = 1.0 + (key.row - key_prev.row) * 0.5
				@fastmath stroke_effort *= travel
			else
				same_hand_streak = 1
			end
			key_prev = key
			@fastmath score += stroke_effort
		end
		println(score / char_count)
	end
end

function prepare_corpus()

end

function print_layout(layout::Layout)
	println("something")
end

function update_layout(layout::Layout)
	println("something")
end

# chars = [['a', 'v'] ['c', 'f']]
# chars = ['a' 'v'; 'c' 'f']

# fingers = [
# 	4 3 2 1 1 2 3 4
# 	4 3 2 1 1 2 3 4
# 	4 3 2 1 1 2 3 4
# ]
# char_list = [
	# 	'b', 'p', 'l', 'd', 'g', 'f', 'u', 'j',
	# 	's', 't', 'n', 'r', 'a', 'e', 'i', 'o',
	# 	'v', 'm', 'h', 'c', 'z', 'y', 'w', 'k']
	
	# x = ['b', 'p', 'l', 'd', 'g', 'f', 'u', 'j', 's', 't', 'n', 'r', 'a', 'e', 'i', 'o', 'v', 'm', 'h', 'c', 'z', 'y', 'w', 'k']
	# dump(x)
	
	
	
	
	# dict['a'], dict['b'] = dict['b'], dict['a']
	
	# print(dict)
	
	# layout = Layout(dict)
	# println(a.char_map)
	
function main()

	chars = [
		'b' 'p' 'l' 'd' 'g' 'f' 'u' 'j'
		's' 't' 'n' 'r' 'a' 'e' 'i' 'o'
		'v' 'm' 'h' 'c' 'z' 'y' 'w' 'k'
	]
	
	dict = Dict{Char, Key}()

	@inbounds for (i, col) in enumerate(eachcol(chars))
		hand = i <= 4 ? false : true
		finger = i <= 4 ? 5 - i : i - 4
		@inbounds for (j, char) in enumerate(col)
			row = 4 - j
			dict[char] = Key(hand, finger, row)
		end
	end

	display(dict)

	corpus_file = "corpus.txt"
	@time analyze(dict, corpus_file)

end

main()