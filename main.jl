import Unicode: isletter, normalize



struct Key
	hand  ::Bool
	finger::Int
	row   ::Int
	# TODO base effort
end

mutable struct Layout
	layout_chars::Vector{Char}
	score::Float64
	finger_load::Vector{Float64}
end




# naka_rushton(x, p, g) = pow(x / p, g) / (pow(x / p, g) + 1)
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

function mirror!(layout::Layout)
	chars = layout.layout_chars
	perm = [((a - 1) ÷ 8) * 8 + 8 - (a - 1) % 8 for a in 1:24]
	layout.layout_chars = chars[perm]
end

function swap_keys!(layout::Layout, freq_keys_on_home_row::Bool)
	vec = layout.layout_chars
	n::Int = rand(1:8)
	if freq_keys_on_home_row
		for _ in 1:n
			rnd1 = rand([1:8; 17:24])
			rnd2 = rand([1:8; 17:24])
			vec[rnd1], vec[rnd2] = vec[rnd2], vec[rnd1]
		end
		for _ in 1:round(3.0 * rand(Float64))
			rnd1 = rand([9:16])
			rnd2 = rand([9:16])
			vec[rnd1], vec[rnd2] = vec[rnd2], vec[rnd1]
		end
	else
		for _ in 1:n
			rnd1 = rand(1:24)
			rnd2 = rand(1:24)
			vec[rnd1], vec[rnd2] = vec[rnd2], vec[rnd1]
		end
	end
end

function make_char_dict(layout_chars)
	char_key_dict::Dict{Char, Int} = Dict(layout_chars[i] => i for i in 1:24)
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
	stroke_effort::Float64 = settings.finger_efforts[key.finger]
	if key.row != 2
		stroke_effort *= settings.not_home_row
	end
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
		travel = 1.0 + abs(key_1.row - key_2.row) * 0.5
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
		f[finger_idx] += letter_data[string(char)] * settings.finger_efforts[key.finger]  # TODO 
	end
	return f
end

function how_hard_to_learn(char_key_dict, key_objects)
	for char in char_key_dict  # TODO check if in both?
		key_1::Key = key_objects[char_key_dict_ref[char]]
		key_2::Key = key_objects[char_key_dict[char]]
		key_diff::Float64 = 1.0
		if key_1.hand != key_2.hand
			key_diff *= 2.0 end
		if key_1.finger != key_2.finger
			key_diff *= 1.5 end
		if key_1.row != key_2.row
			key_diff *= 1.25 end
		# TODO 
	end
	return 1.0
end

function analyze_layout(layout, letter_data, bigram_data, key_objects::Tuple, settings, letters)::Float64
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_load = get_finger_load(char_key_dict, letter_data, key_objects, settings)  # TODO 
	
	score_letters = analyze_ngrams(letter_data, analyze_letter, char_key_dict, key_objects, settings, letters)
	score_bigrams = analyze_ngrams(bigram_data, analyze_bigram, char_key_dict, key_objects, settings, letters)

	# how_hard_to_learn = how_hard_to_learn()
	
	score::Float64 = (score_letters + score_bigrams) * 0.5
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
				swap_keys!(tmp_layout, settings.freq_keys_on_home_row)
				# mirror!(tmp_layout)  # TODO 
				if layout.layout_chars == tmp_layout.layout_chars
					continue
				end
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


# using Plots


function main()
	
	settings = (
		lang_prefs = Dict("en" => 1.0),
		finger_efforts = (1.2, 1.0, 1.5, 2.3),
		sfb = 4.0,
		inroll = 0.7,
		outroll = 1.2,
		alter = 0.75,
		freq_keys_on_home_row = false,
		not_home_row = 2.0,
		keep_familiar = 0.5,
		enforce_balance = 1.0,  # TODO 
		prefer_bottom_row = 0.0  # TODO # lang_prefs = Dict("en" => 0.7, "cs" => 0.3),   Dict("en" => 1.0),
	)

	@time optimize_layout(64, 4096, settings)
	# XXX duplicate "you" on line 8474 in "en" has non ascii

end

main()