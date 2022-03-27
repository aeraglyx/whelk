struct Key
	hand  ::Bool
	finger::Int
	row   ::Int
	# TODO base effort
end

mutable struct Layout
	char_key_dict::Dict{Char, Key}  # TODO vector of pairs ?
	score::Float64
end


function naka_rushton(x::Float64, p::Float64, g::Float64)::Float64
	tmp = (x / p) ^ g
	return tmp / (tmp + 1.0)
end

function discard_bad_layouts!(layouts, pivot::Float64, gamma::Float64)
	new = [layout for (i, layout) in enumerate(layouts) if naka_rushton(convert(Float64, i), pivot, gamma) < rand(Float64)]
	return new
end  # TODO 

# function naka_rushton(x, p, g) = pow(x / p, g) / (pow(x / p, g) + 1)


function print_layout(layout::Layout)
	println("something")
end

function swap_keys!(layout::Layout)
	keys = collect(keys(layout.char_key_dict))
	keys[1], keys[2] = keys[2], keys[1]  # TODO 
end

function get_word_freq_data(lang_prefs::Dict{String, Float64}, n::Int)::Dict{String, Float64}
	datax = Dict{String, Float64}()
	for (lang, weight) in lang_prefs
		data_filename = "freq_data/" * lang * "_50k.txt"
		data = Vector{Tuple{String, Int64}}(undef, n)
		freq_total::UInt = 0
		open(data_filename, "r") do file
			for i in 1:n
				word, freq = split(readline(file), " ")
				word = Base.Unicode.normalize(string(word), stripmark=true, casefold=true)
				freq = parse(UInt, freq)
				freq_total += freq
				data[i] = (word, freq)
			end
		end
		mergewith!(+, datax, Dict(word => freq * weight / freq_total for (word, freq) in data))
	end
	return datax
end

function analyze_char(char::Char, char_key_dict)
	key::Key = char_key_dict[char]
	finger_strengths = (1.2, 1.0, 1.5, 2.3)
	stroke_effort::Float64 = finger_strengths[key.finger]
	if key.row != 2
		stroke_effort *= 1.5
	end
end

function analyze_chars(char_data, char_key_dict)::Float64
	score::Float64 = 0.0
	for (char, freq) in char_data
		char_score = analyze_char(char, char_key_dict)
		score += char_score * freq
	end
	return score
end

function analyze_bigram(bigram::String, char_key_dict)

	# TODO precompute key-key pairs ?
	
	SFB_PENALTY ::Float64 = 4.0
	INWARD_ROLL ::Float64 = 0.7
	OUTWARD_ROLL::Float64 = 1.2
	
	key_1::Key = char_key_dict[bigram[1]]
	key_2::Key = char_key_dict[bigram[2]]
	
	finger_strengths = (1.2, 1.0, 1.5, 2.3)
	trans_effort::Float64 = (finger_strengths[key_1.finger] + finger_strengths[key_2.finger]) * 0.5

	if key_1.hand == key_2.hand
		if key.finger == key_2.finger
			trans_effort *= SFB_PENALTY
		elseif key_1.finger < key_2.finger
			trans_effort *= INWARD_ROLL
		elseif key_1.finger > key_2.finger
			trans_effort *= OUTWARD_ROLL
		end
		travel = 1.0 + (key_1.row - key_2.row) * 0.5
		trans_effort *= travel
	end
	return trans_effort
end

function analyze_bigrams(bigram_data, char_key_dict)::Float64
	score::Float64 = 0.0
	for (bigram, freq) in bigram_data
		bigram_score = analyze_bigram(bigram, char_key_dict)
		score += bigram_score * freq
	end
	return score
end

function analyze_word(word::String, dict::Dict{Char, Key})::Float64

	SFB_PENALTY ::Float64 = 4.0
	INWARD_ROLL ::Float64 = 0.7
	OUTWARD_ROLL::Float64 = 1.2

	score::Float64 = 0.0
	key_prev = false
	same_hand_streak::Int64 = 0

	for char in word

		if !haskey(dict, char)
			key_prev = false
			continue
		end
		
		key = dict[char]
		
		finger_strengths = (1.2, 1.0, 1.5, 2.3)
		stroke_effort::Float64 = 0.0
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

function analyze_v2(layout, data)

	char_key_dict = layout.char_key_dict
	# score::Float64 = 0.0

	char_data = get_char_data()
	bigram_data = get_bigram_data()

	score_chars = analyze_chars(char_data, char_key_dict)
	score_bigrams = analyze_bigrams(bigram_data, char_key_dict)

	score::Float64 = score_chars * 0.5 + score_bigrams * 0.5
	layout.score = score
end

function analyze(layout, data)
	dict = layout.char_key_dict
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
	layout.score = score
end

function optimize_layout(layout::Layout, lang_prefs, iter::Int = 64, data_length::Int = 4096)
	freq_data = get_word_freq_data(lang_prefs, data_length)
	analyze(layout, freq_data)
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
				analyze(tmp_layout, freq_data)
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
	# print(layout.char_key_dict)
	
	lang_prefs = Dict("en" => 0.7, "cs" => 0.3)
	@time optimize_layout(layout, lang_prefs, 4, 1024)

end

main()