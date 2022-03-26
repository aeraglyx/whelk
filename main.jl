mutable struct Key
	hand  ::Bool
	finger::Int
	row   ::Int
end

mutable struct Layout
	char_key_dict::Dict{Char, Key}
	score::Float64
end





function print_layout(layout::Layout)
	println("something")
end

function prep_freq_data(freq_file::String, n::Int)
	data = Vector{Tuple{String, Int64}}(undef, n)
	freq_total::Int = 0
	open(freq_file, "r") do file
		for i in 1:n
			word, freq = split(readline(file), " ")
			freq = parse(Int, freq)
			freq_total += freq
			data[i] = (string(word), freq)
		end
	end
	data = [(word, freq / freq_total) for (word, freq) in data]
	return data
end

function analyze_word(word, dict)::Float64

	SFB_PENALTY ::Float64 = 4.0
	INWARD_ROLL ::Float64 = 0.7
	OUTWARD_ROLL::Float64 = 1.2

	score::Float64 = 0.0
	key_prev = false
	same_hand_streak::Int64 = 0

	for char in word
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

		finger_strengths = (1.2, 1.0, 1.5, 2.3)
		stroke_effort = finger_strengths[key.finger]
		
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
				# TODO redirects
				end
				travel = 1.0 + (key.row - key_prev.row) * 0.5
				stroke_effort *= travel  # TODO assume hand starts at home row
			else
				same_hand_streak = 1
			end
		end
		key_prev = key
		score += stroke_effort
	end
	return score / length(word)
end

function analyze(dict, data)
	score::Float64 = 0.0
	# sfb_count = 0
	# roll_count = 0
	# left_hand_count = 0
	for entry in data
		word, freq = entry
		word_score::Float64 = 0.0
		word_score = analyze_word(word, dict)
		score += word_score * freq
	end
	# println(score)
	return score
end

function analyze_multilang(dict, lang_prefs, data_length::Int)
	score::Float64 = 0.0
	for (lang, weight) in lang_prefs
		data_filename = lang * "_50k.txt"
		print(data_filename)
		freq_data = prep_freq_data(data_filename, data_length)
		score += analyze(dict, freq_data) * weight
	end
	return score
end


function optimize_layout(layout, lang_prefs, iter::Int, data_length::Int = 4096)
	# analyze(layout.char_key_dict, data)
	analyze_multilang(layout.char_key_dict, lang_prefs, data_length)
	print("yes")
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
	
	layout = Layout(char_key_dict, Inf)
	
	# lang_prefs = Dict("en" => 0.7, "cs" => 0.3)
	lang_prefs = Dict("en" => 1.0)
	@time optimize_layout(layout, lang_prefs, 1)

end

main()