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



# const SFB_PENALTY  = 4.0::Float64
# const INWARD_ROLL  = 0.7::Float64
# const OUTWARD_ROLL = 1.2::Float64

function analyze(dict, data)

	SFB_PENALTY ::Float64 = 4.0
	INWARD_ROLL ::Float64 = 0.7
	OUTWARD_ROLL::Float64 = 1.2
	
	score::Float64 = 0.0
	
	# sfb_count = 0
	# roll_count = 0
	# left_hand_count = 0
		
	for entry in data
		
		word, freq = entry
		word_score::Float64 = 0.0
		key_prev = false
		same_hand_streak::Int64 = 0
		# print(file)
		for char in word  # TODO function for analyzing a single word
		# while !eof(file)
			# char = lowercase(read(file, Char))
			# char_count += 1
			if !haskey(dict, char)  # TODO make sure there are already no illegal chars
				key_prev = false
				# same_hand_streak += 0.5
				# left_hand_count += 0.5
				continue
			end
			
			key = dict[char]
						
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
				stroke_effort *= 1.5
			end
			
			if key_prev != false
				if key.hand == key_prev.hand
					stroke_effort *= 1 + same_hand_streak * 0.25
					same_hand_streak += 1
					if key.finger == key_prev.finger
						stroke_effort *= SFB_PENALTY
						# sfb_count += 1
					elseif key.finger < key_prev.finger
						stroke_effort *= INWARD_ROLL
						# roll_count += 1
					elseif key.finger > key_prev.finger
						stroke_effort *= OUTWARD_ROLL
						# roll_count += 1
					end
					travel = 1.0 + (key.row - key_prev.row) * 0.5
					stroke_effort *= travel  # TODO assume hand starts at home row
				else
					same_hand_streak = 1
				end
			end

			key_prev = key
			word_score += stroke_effort
		end
		score += word_score * freq / length(word)  # TODO loop i for chars for faster len ?
	end
	println(score)
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
	
	
	
	
	# char_key_dict['a'], char_key_dict['b'] = char_key_dict['b'], char_key_dict['a']
	
	# print(dict)
	
	# layout = Layout(dict)
	# println(a.char_map)

using DelimitedFiles


function prep_freq_data(freq_file::String, n::Int)
	data = Vector{Tuple{String, Int64}}(undef, n)
	freq_total::Int = 0
	open(freq_file, "r") do file
		for i in 1:n
			word, freq = split(readline(file), " ")
			freq = parse(Int, freq)
			freq_total += freq
			data[i] = (string(word), freq)
			# println(line)
		end
	end
	data = [(word, freq / freq_total) for (word, freq) in data]
	# display(data)
	return data
end
	
function main()

	chars = [
		'b' 'p' 'l' 'd' 'g' 'f' 'u' 'j'
		's' 't' 'n' 'r' 'a' 'e' 'i' 'o'
		'v' 'm' 'h' 'c' 'z' 'y' 'w' 'k'
	]
	
	char_key_dict = Dict{Char, Key}()

	for (i, col) in enumerate(eachcol(chars))
		hand = i <= 4 ? false : true
		finger = i <= 4 ? 5 - i : i - 4
		for (j, char) in enumerate(col)
			row = 4 - j
			char_key_dict[char] = Key(hand, finger, row)
		end
	end

	# display(char_key_dict)

	# corpus_file = "corpus.txt"
	# texts = readdir("texts", join=true)
	# word_freq = "en_50k.txt"
	data = prep_freq_data("en_50k.txt", 8192)
	# print(data)
	@time analyze(char_key_dict, data)

end

main()
