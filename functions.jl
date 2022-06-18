import Unicode: isletter, normalize



function naka_rushton(x::Float64, p::Float64, g::Float64)::Float64
	tmp = (x / p) ^ g
	return tmp / (tmp + 1.0)
end

function discard_bad_layouts!(layouts, pivot::Float64, gamma::Float64)
	# new = [layout for (i, layout) in enumerate(layouts) if naka_rushton(convert(Float64, i), pivot, gamma) < rand(Float64)]
	new = Vector{Layout}()
	for (i, layout) in enumerate(layouts)
		if naka_rushton(convert(Float64, i) - 1.0, pivot, gamma) < rand(Float64)
			push!(new, layout)
		# else
		end
		# layout = nothing
	end
	return new
end

function print_layout(layout::Layout)
	chars = layout.layout_chars
	println(join(chars[1:4],   ' ') * "  " * join(chars[5:8],   ' '))
	println(join(chars[9:12],  ' ') * "  " * join(chars[13:16], ' '))
	println(join(chars[17:20], ' ') * "  " * join(chars[21:24], ' '))
end

function swap_keys!(layout::Layout)
	chars = layout.layout_chars
	n::Int = rand(1:8)
	for _ in 1:n
		rnd1 = rand(1:24)
		rnd2 = rand(1:24)
		chars[rnd1], chars[rnd2] = chars[rnd2], chars[rnd1]
	end
end

function mirror_chars(chars)
	perm = [((a - 1) ÷ 8) * 8 + 8 - (a - 1) % 8 for a in 1:24]
	return chars[perm]
end

function normalize_vowels!(layout::Layout, vowel_side)
	chars = layout.layout_chars
	left_chars = chars[1:4; 9:12; 17:20]
	vowels = ['a', 'e', 'i', 'y', 'o', 'u']
	n = length(intersection(left_chars, vowels))
	if (!vowel_side && n < 3) || (vowel_side && n > 3)
		layout.layout_chars = mirror_chars(chars)
	end
end

function make_char_dict(layout_chars)
	char_key_dict::Dict{Char, Int} = Dict(layout_chars[i] => i for i in 1:24)
	return char_key_dict
end

function make_char_dict_ref(settings.ref)
	layout_chars = normalize(string(layout_chars), stripmark=true, casefold=true)
	# layout_chars = filter(isascii, layout_chars)
	# layout_chars = filter(isletter, layout_chars)
	char_key_dict::Dict{Char, Int} = Dict(layout_chars[i] => i for i in 1:24)
	# TODO filter only letters
	return char_key_dict
end

function get_word_data(lang_prefs::Dict{String, Float64}, n::Int)::Dict{String, Float64}
	datax = Dict{String, Float64}()
	for (lang, weight) in lang_prefs
		data_filename = "freq_data/" * lang * "_50k.txt"
		data_per_lang = Dict{String, Float64}()
		freq_total::UInt = 0
		open(data_filename, "r") do file
			for _ in 1:n
				word, freq = split(readline(file), ' ')
				word = normalize(string(word), stripmark=true, casefold=true)
				word = filter(isascii, word)
				word = filter(isletter, word)
				freq = parse(UInt, freq)
				freq_total += freq
				data_per_lang[word] = freq
			end
		end
		mergewith!(+, datax, Dict(word => freq * weight / freq_total for (word, freq) in data_per_lang))
	end
	return datax
end

function ngrams_from_word(word, n)
	return [view(word, i:i+n-1) for i = 1:length(word)-n+1]
end

function get_ngram_data(word_freq_data::Dict{String, Float64}, n::Int)
	bigram_data = Dict{SubString, Float64}()
	for (word, freq) in word_freq_data
		if length(word) < n
			continue
		end
		for ngram in ngrams_from_word(word, n)
			if ngram in keys(bigram_data)
				bigram_data[ngram] += freq
			else
				bigram_data[ngram] = freq
			end
		end
	end
	freq_total = sum(values(bigram_data))
	bigram_data = Dict(ngram => freq / freq_total for (ngram, freq) in bigram_data)
	return bigram_data
end

function stroke_effort(key, settings)::Float64
	stroke_effort::Float64 = 1 / settings.finger_strengths[key.finger]
	if key.row != 2
		stroke_effort *= settings.home_row
	end
	stroke_effort *= 2 ^ ((key.row - 2) * settings.prefer_bottom_row)
	return stroke_effort
end

function analyze_letter(char::SubString, char_key_dict, key_objects, settings)::Float64
	key::Key = key_objects[char_key_dict[only(char)]]
	return stroke_effort(key, settings)
end

function analyze_bigram(bigram::SubString, char_key_dict, key_objects, settings)::Float64

	# TODO precompute key-key pairs ?
	
	key_1::Key = key_objects[char_key_dict[bigram[1]]]
	key_2::Key = key_objects[char_key_dict[bigram[2]]]
	
	trans_effort::Float64 = (stroke_effort(key_1, settings) + stroke_effort(key_2, settings)) * 0.5

	if key_1.hand == key_2.hand
		if key_1.finger == key_2.finger
			trans_effort *= settings.sfb
		elseif key_1.finger > key_2.finger
			trans_effort *= settings.inroll
		elseif key_1.finger < key_2.finger
			trans_effort *= settings.outroll
		end
		travel = 1.0 + abs(key_1.row - key_2.row) * settings.row_change
		trans_effort *= travel
	else
		trans_effort *= settings.alter
	end
	return trans_effort
end

# TODO trigrams

function analyze_ngrams(ngram_data, analyze_ngram, char_key_dict, key_objects, settings, letters)::Float64
	score::Float64 = 0.0
	for (ngram, freq) in ngram_data
		if issubset(collect(ngram), letters)
			ngram_score = analyze_ngram(ngram, char_key_dict, key_objects, settings)
			score += ngram_score * freq
		end
	end
	return score
end

function get_finger_load(char_key_dict, letter_data, key_objects, settings)
	f = Vector{Float64}(undef, 8)
	f = zeros(8)
	for (char, key_idx) in char_key_dict
		key = key_objects[key_idx]
		finger_idx = key.hand ? 4 + key.finger : 5 - key.finger
		f[finger_idx] += letter_data[string(char)] / settings.finger_strengths[key.finger]  # TODO 
	end
	return f
end

function how_hard_to_learn(char_key_dict, key_objects, settings, letter_data)
	char_key_dict_ref = make_char_dict_ref(settings.ref)
	total::Float64 = 0.0
	
	for char in char_key_dict
		
		if char ∉ keys(char_key_dict_ref)  # ∈ ∉ not in
			continue end
		
		key_1::Key = key_objects[char_key_dict[char]]
		key_2::Key = key_objects[char_key_dict_ref[char]]

		key_diff::Float64 = 1.0
		if key_1.hand != key_2.hand
			key_diff *= 2.0 end
		if key_1.finger != key_2.finger
			key_diff *= 1.5 end
		if key_1.row != key_2.row
			key_diff *= 1.25 end
		
		freq = letter_data[char]
		key_diff *= freq
		
		freq_total += freq
		total += key_diff
	end
	return total / freq_total
end

function analyze_layout(layout, letter_data, bigram_data, key_objects::Tuple, settings, letters)::Float64
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_load = get_finger_load(char_key_dict, letter_data, key_objects, settings)  # TODO 
	
	score_letters = analyze_ngrams(letter_data, analyze_letter, char_key_dict, key_objects, settings, letters)
	score_bigrams = analyze_ngrams(bigram_data, analyze_bigram, char_key_dict, key_objects, settings, letters)
	how_hard_to_learn = how_hard_to_learn(char_key_dict, key_objects, settings, letter_data)

	score::Float64 = (score_letters + score_bigrams) * 0.5
	score *= how_hard_to_learn

	layout.score = score
	layout.finger_load = finger_load

	return score
end

function get_char_array(key_objects, letter_data, settings)
	efforts = Vector{Float64}(undef, 24)
	efforts = [stroke_effort(key, settings) for key in key_objects]
	letters = sort!(collect(letter_data), by=x->x[2], rev=true)  # TODO ?
	letters = [only(letter.first) for letter in letters][1:24]
	return letters
end

function get_char_array_v2(key_objects, letter_data, settings)
	efforts = Vector{Float64}(undef, 24)
	efforts = [stroke_effort(key, settings) for key in key_objects]
	letters = collect(letter_data)
	letters = [only(letter.first) for letter in letters]
	freq = [letter.second for letter in letters]
	effort_perm = sortperm(efforts)
	freq_perm = sortperm(freq)
	letters[freq_perm][effort_perm][1:24]
	return letters
end

function optimize_layout(iter::Int, data_length::Int, settings)

	key_objects = (
		Key(false, 4, 1),
		Key(false, 3, 1),
		Key(false, 2, 1),
		Key(false, 1, 1),
		Key(true,  1, 1),
		Key(true,  2, 1),
		Key(true,  3, 1),
		Key(true,  4, 1),
		Key(false, 4, 2),
		Key(false, 3, 2),
		Key(false, 2, 2),
		Key(false, 1, 2),
		Key(true,  1, 2),
		Key(true,  2, 2),
		Key(true,  3, 2),
		Key(true,  4, 2),
		Key(false, 4, 3),
		Key(false, 3, 3),
		Key(false, 2, 3),
		Key(false, 1, 3),
		Key(true,  1, 3),
		Key(true,  2, 3),
		Key(true,  3, 3),
		Key(true,  4, 3)
	)

	word_data = get_word_data(settings.lang_prefs, data_length)
	letter_data = get_ngram_data(word_data, 1)
	bigram_data = get_ngram_data(word_data, 2)

	letters = get_char_array(key_objects, letter_data, settings)  # TODO clean up data so it doesnt contain unused chars?

	layout = Layout(letters, Inf, Vector{Float64}(undef, 8))
	normalize_vowels!(layout, settings.vowel_side)
	print_layout(layout)

	analyze_layout(layout, letter_data, bigram_data, key_objects, settings, letters)
	layouts = [layout]
	last_best_layout = layout
	for _ in 1:iter
		layouts_copy = deepcopy(layouts)
		for layout in layouts_copy
			new_layouts = []
			while length(new_layouts) < 32
				tmp_layout = deepcopy(layout)
				swap_keys!(tmp_layout)
				normalize_vowels!(tmp_layout, settings.vowel_side)
				# mirror!(tmp_layout)  # TODO 
				if layout.layout_chars == tmp_layout.layout_chars
					continue end
				analyze_layout(tmp_layout, letter_data, bigram_data, key_objects, settings, letters)
				push!(new_layouts, tmp_layout)
			end
			sort!(new_layouts, by = layout -> layout.score, rev = false)
			new_layouts = discard_bad_layouts!(new_layouts, 64.0, 4.0)
			append!(layouts, new_layouts)
		end
		sort!(layouts, by = layout -> layout.score, rev = false)
		layouts = discard_bad_layouts!(layouts, 256.0, 4.0)
		best_layout_so_far = layouts[1]
		if best_layout_so_far.layout_chars != last_best_layout.layout_chars
			println("Best layout so far:")
			print_layout(best_layout_so_far)
			println(best_layout_so_far.score)
			# p = plot(best_layout_so_far.finger_load)
			# gui(p)
			# best_layout_so_far.print_stats()
		end
		last_best_layout = best_layout_so_far
	end
	# print_layout.(layouts)
	# print("yes")
end