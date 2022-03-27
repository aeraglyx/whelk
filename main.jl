struct Key
	hand  ::Bool
	finger::Int
	row   ::Int
end

mutable struct Layout
	char_key_dict::Dict{Char, Key}
	score::Float64
end


function naka_rushton(x::Float64, p::Float64, g::Float64)::Float64
	tmp = (x / p) ^ g
	return tmp / (tmp + 1.0)
end

function discard_bad_layouts!(layouts, pivot::Float64, gamma::Float64)
	return [layout for (i, layout) in enumerate(layouts) if naka_rushton(convert(Float64, i), pivot, gamma) < rand(Float64)]
end  # TODO 

# function naka_rushton(x, p, g) = pow(x / p, g) / (pow(x / p, g) + 1)


function print_layout(layout::Layout)
	println("something")
end

function swap_keys!(layout::Layout)
	char_key_dict = layout.char_key_dict
	char_key_dict['a'], char_key_dict['b'] = char_key_dict['b'], char_key_dict['a']
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
		freq_data = prep_freq_data(data_filename, data_length)
		score += analyze(dict, freq_data) * weight
	end
	return score
end


function optimize_layout(layout, lang_prefs, iter::Int = 64, data_length::Int = 4096)
	# analyze(layout.char_key_dict, data)
	analyze_multilang(layout.char_key_dict, lang_prefs, data_length)
	layouts = [layout]
	last_best_layout = layout
	for i in 1:iter
		layouts_copy = deepcopy(layouts)
		for layout in layouts_copy
			new_layouts = []
			while length(new_layouts) < 32
				tmp_layout = deepcopy(layout)
				swap_keys!(tmp_layout)
				if layout.char_key_dict == tmp_layout.char_key_dict
					continue
				end
				analyze_multilang(tmp_layout.char_key_dict, lang_prefs, data_length)
				push!(new_layouts, tmp_layout)
			end
			sort!(new_layouts, by = layout -> layout.score, rev = false)
			new_layouts = discard_bad_layouts!(new_layouts, 16.0, 4.0)
			append!(layouts, new_layouts)
			# TODO possible dupli
		end
		# del layouts_copy
		sort!(layouts, by = layout -> layout.score, rev = false)
		layouts = discard_bad_layouts!(layouts, 64.0, 4.0)
		print(length(layouts))
		
		best_layout_so_far = layouts[1]
		if best_layout_so_far.char_key_dict != last_best_layout.char_key_dict
			# print("\n", end="")
			# print(f"Iteration {str(i + 1).zfill(len(str(iter)))} / {iter}")
			println("Best layout so far:")
			# print(best_layout_so_far)
			# best_layout_so_far.print_stats()
		end
		last_best_layout = best_layout_so_far
	end
	# print("yes")
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
	@time optimize_layout(layout, lang_prefs, 4)

end

main()