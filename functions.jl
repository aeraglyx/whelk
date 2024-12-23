import Unicode: isletter, normalize

using TOML
using HTTP



function get_settings(config)
	dict = TOML.parsefile(config)
	settings = (; (Symbol(k) => v for (k,v) in dict)...)
	return settings
end

function naka_rushton(x::Float64, p::Float64, g::Float64)::Float64
	x = max(0, x - 4)  # so it never deletes the best 4
	tmp = (x / p) ^ g
	return tmp / (tmp + 1.0)
end

function discard_bad_layouts!(layouts, pivot::Float64, gamma::Float64)
	new = Vector{Layout}()
	for (i, layout) in enumerate(layouts)
		if naka_rushton(convert(Float64, i) - 1.0, pivot, gamma) < rand(Float64)
			push!(new, layout)
		end
	end
	return new
end

function print_layout(layout::Layout)
	chars = layout.layout_chars
	middle_string = " *  * "
	println(join(chars[1:4],   ' '), middle_string, join(chars[5:8],   ' '))
	println(join(chars[9:12],  ' '), middle_string, join(chars[13:16], ' '))
	println(join(chars[17:20], ' '), middle_string, join(chars[21:24], ' '))
end

function swap_keys!(layout::Layout)
	chars = layout.layout_chars
	n::UInt8 = rand(1:8)
	for _ in 1:n
		rnd1::UInt8 = rand(1:24)
		rnd2::UInt8 = rand(1:24)
		chars[rnd1], chars[rnd2] = chars[rnd2], chars[rnd1]
	end
	# TODO swap vowels only on one hand
end

function mirror_index(x::Int)::Int
	return ((x - 1) ÷ 8) * 8 + 8 - (x - 1) % 8
end

function mirror_chars(chars)
	perm = [mirror_index(x) for x in 1:24]
	return chars[perm]
end

function normalize_vowels!(layout::Layout, vowel_side)
	chars = layout.layout_chars
	left_chars = chars[[1:4; 9:12; 17:20]]
	vowels = ['a', 'e', 'i', 'y', 'o', 'u']
	n = length(intersect(left_chars, vowels))
	if (!vowel_side && n < 3) || (vowel_side && n > 3)
		layout.layout_chars = mirror_chars(chars)
	end
	# TODO weight vowels by their freq
end

function make_char_dict(layout_chars)::Dict{Char, UInt8}
	char_key_dict::Dict{Char, UInt8} = Dict(layout_chars[i] => i for i in 1:24)
	return char_key_dict
end

function make_char_dict_ref(ref_layout)::Dict{Char, UInt8}
	# layout_chars = normalize(string(ref_layout), stripmark=true, casefold=true)
	layout_chars = [only(x) for x in split(ref_layout)]
	char_key_dict::Dict{Char, UInt8} = Dict(layout_chars[i] => i for i in 1:24)
	char_key_dict = filter(x -> isletter(first(x)), char_key_dict)
	return char_key_dict
end

function get_data(lang)::String
	url_base = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/"
	url = url_base * lang * "/" * lang * "_50k.txt"
	data = HTTP.request("GET", url).body
	data = strip(String(data))
	return data
end

function get_word_data(langs::Dict{String, Any})::Dict{String, Float64}
	datax = Dict{String, Float64}()
	for (lang, weight) in langs
		weight == 0.0 && continue
		data_per_lang = Dict{String, Float64}()
		freq_total::UInt = 0
		data = get_data(lang)
		for line in split(data, "\n")
			word, freq = split(line, ' ')
			word = normalize(string(word), stripmark=true, casefold=true)
			word = filter(isascii, word)
			word = filter(isletter, word)
			freq = parse(UInt, freq)
			freq_total += freq
			data_per_lang[word] = freq
		end
		mergewith!(+, datax, Dict(word => freq * weight / freq_total for (word, freq) in data_per_lang))
	end
	return datax
end

function ngrams_from_word(word, n)
	return [view(word, i:i+n-1) for i = 1:length(word)-n+1]
end

function normalize_dict!(dict)
	value_total = sum(values(dict))
	dict = Dict(key => value/value_total for (key, value) in dict)
	return dict
end

function filter_dict!(dict, threshold)
	sorted_pairs = sort(collect(dict), by=x->x[2], rev=true)
	freq_total::Float64 = 0.0
	for (i, thing) in enumerate(sorted_pairs)
		freq_total += thing[2]
		if freq_total >= threshold
			dict = Dict(sorted_pairs[1:i])
			break
		end
	end
	return dict
end

function get_letter_freqs(word_freq_data::Dict{String, Float64})
	letter_freqs = Dict{Vector{Char}, Float64}()
	for (word, freq) in word_freq_data
		for letter in word  # todo
			# !(letter[1] in letters) && continue
			if [letter] in keys(letter_freqs)
				letter_freqs[[letter]] += freq
			else
				letter_freqs[[letter]] = freq
			end
		end
	end
	letter_freqs = Dict(sort(collect(letter_freqs), by=x->x[2], rev=true)[1:24])
	letter_freqs = normalize_dict!(letter_freqs)
	return letter_freqs
end

function get_bigram_freqs(word_freq_data::Dict{String, Float64}, letters, settings)
	bigram_freqs = Dict{SubString, Float64}()
	for (word, freq) in word_freq_data
		length(word) < 2 && continue
		for ngram in ngrams_from_word(word, 2)
			!issubset(collect(ngram), letters) && continue
			if ngram in keys(bigram_freqs)
				bigram_freqs[ngram] += freq
			else
				bigram_freqs[ngram] = freq
			end
		end
	end
	total = length(bigram_freqs)
	bigram_freqs = normalize_dict!(bigram_freqs)
	bigram_freqs = filter_dict!(bigram_freqs, settings.bigram_quality)
	bigram_freqs = normalize_dict!(bigram_freqs)
	println(length(bigram_freqs), " / ", total, " bigrams")
	return bigram_freqs
end

function get_bigram_freqs_v2(word_freq_data::Dict{String, Float64}, letters, settings)
	bigram_freqs = Dict{SubString, Float64}()

	for (word, freq) in word_freq_data
		word_length = length(word)
		word_length < 2 && continue

		for n in 2:word_length
			for ngram in ngrams_from_word(word, n)
				bigram = ngram[[begin, end]]
				!issubset(collect(bigram), letters) && continue
				weight = settings.skipgram_weight ^ (n - 1)
				if bigram in keys(bigram_freqs)
					bigram_freqs[bigram] += freq * weight
				else
					bigram_freqs[bigram] = freq * weight
				end
			end
		end
	end

	total = length(bigram_freqs)
	bigram_freqs = normalize_dict!(bigram_freqs)
	bigram_freqs = filter_dict!(bigram_freqs, settings.bigram_quality)
	bigram_freqs = normalize_dict!(bigram_freqs)
	println(length(bigram_freqs), " / ", total, " bigrams")
	return bigram_freqs
end

function get_trigram_freqs(word_freq_data::Dict{String, Float64}, letters, settings)
	trigram_freqs = Dict{SubString, Float64}()
	for (word, freq) in word_freq_data
		length(word) < 3 && continue
		for ngram in ngrams_from_word(word, 3)
			!issubset(collect(ngram), letters) && continue
			if ngram in keys(trigram_freqs)
				trigram_freqs[ngram] += freq
			else
				trigram_freqs[ngram] = freq
			end
		end
	end
	total = length(trigram_freqs)
	trigram_freqs = normalize_dict!(trigram_freqs)
	trigram_freqs = filter_dict!(trigram_freqs, settings.trigram_quality)
	trigram_freqs = normalize_dict!(trigram_freqs)
	println(length(trigram_freqs), " / ", total, " trigrams\n")
	return trigram_freqs
end

function strength(x, independence::Float64)::Float64
	return 2.0 ^ (- float(x) * independence)
end

function stroke_effort(key, settings)::Float64
	stroke_effort::Float64 = 1.0 / settings.finger_strengths[key.finger]
	if key.row != 2
		stroke_effort *= (1.0 + abs(key.row - 2) * settings.off_home)
	end
	# stroke_effort *= 2.0 ^ ((key.row - 2.0) * settings.prefer_top_row)
	return stroke_effort
end

function analyze_letter(char, key_objects, settings)::Float64
	key::Key = key_objects[char[1]]
	return stroke_effort(key, settings)
end

function analyze_bigram(bigram, key_objects, settings)::Float64

	key_1::Key = key_objects[bigram[1]]
	key_2::Key = key_objects[bigram[2]]

	effort::Float64 = (stroke_effort(key_1, settings) + stroke_effort(key_2, settings)) / 2.0

	if key_1.hand == key_2.hand
		x = key_2.finger - key_1.finger
		y = key_2.row - key_1.row

		if x == 0
			# same finger
			effort *= settings.sfb * (1.0 + y * y)
		else
			# 1.0 for neighboring fingers and slowly decaying
			dependence = 2.0 ^ ((1 - abs(x)) * settings.independence)

			if y != 0
				# scissor
				effort *= 1.0 + settings.scissor * y * y * dependence
			end

			# rolls
			x < 0 && (effort *= (1.0 + settings.inroll * dependence))
			x > 0 && (effort *= (1.0 + settings.outroll * dependence))
		end

		effort *= settings.one_hand
	end

	return effort
end

function analyze_trigram(trigram, key_objects, settings)::Float64

	key_1::Key = key_objects[trigram[1]]
	key_2::Key = key_objects[trigram[2]]
	key_3::Key = key_objects[trigram[3]]
	
	effort::Float64 = (stroke_effort(key_1, settings) + stroke_effort(key_2, settings) + stroke_effort(key_2, settings)) / 3.0
	
	if key_1.hand == key_3.hand
		# TODO bake DSBFs into bigram freqs
		# effort += 0.5 * analyze_bigram(trigram[1:3 .!= 2], key_objects, settings)

		if key_1.hand == key_2.hand
			if (key_1.finger < key_2.finger > key_3.finger) || (key_1.finger > key_2.finger < key_3.finger)
				effort *= settings.redir
			end
		end
	else
		effort *= settings.sth
	end

	return effort
end

function evaluate_letters(letter_freqs, letter_efforts, char_key_dict)::Float64
	total_freq::Float64 = 0.0
	total_score::Float64 = 0.0
	for (ngram, freq) in letter_freqs
		ngram_score = letter_efforts[char_key_dict[ngram[1]]] * freq
		total_freq += freq
		total_score += ngram_score
	end
	return total_score / total_freq
end

function evaluate_bigrams(bigram_freqs, bigram_efforts, char_key_dict)::Float64
	total_freq::Float64 = 0.0
	total_score::Float64 = 0.0
	for (ngram, freq) in bigram_freqs
		ngram_score = bigram_efforts[char_key_dict[ngram[1]], char_key_dict[ngram[2]]] * freq
		total_freq += freq
		total_score += ngram_score
	end
	return total_score / total_freq
end

function evaluate_trigrams(trigram_freqs, trigram_efforts, char_key_dict)::Float64
	total_freq::Float64 = 0.0
	total_score::Float64 = 0.0
	for (ngram, freq) in trigram_freqs
		ngram_score = trigram_efforts[char_key_dict[ngram[1]], char_key_dict[ngram[2]], char_key_dict[ngram[3]]] * freq
		total_freq += freq
		total_score += ngram_score
	end
	return total_score / total_freq
end

function get_finger_load(char_key_dict, letter_freqs, key_objects, settings)::Float64

	finger_load::Vector{Float64} = zeros(8)
	for (char, key_idx) in char_key_dict
		key = key_objects[key_idx]
		finger_idx = key.hand ? 4 + key.finger : 5 - key.finger
		strength = settings.finger_strengths[key.finger]
		sum_thingy = sum(1 ./ settings.finger_strengths)
		finger_load[finger_idx] += letter_freqs[[char]] / strength * sum_thingy
	end

	balance = settings.enforce_balance
	return 2 ^ (balance * sum(abs.(log2.(finger_load))) / 8)
end

function how_hard_to_learn(char_key_dict, key_objects, settings, letter_freqs)::Float64
	
	iszero(settings.keep_familiar) && (return 1.0)

	char_key_dict_ref = make_char_dict_ref(settings.ref_layout)
	total::Float64 = 0.0
	freq_total::Float64 = 0.0
	
	for char in keys(char_key_dict)

		char ∉ keys(char_key_dict_ref) && continue  # ∈ ∉ not in
		
		key_1::Key = key_objects[char_key_dict[char]]
		key_2::Key = key_objects[char_key_dict_ref[char]]

		key_diff::Float64 = 1.0

		key_1.hand != key_2.hand && (key_diff *= 2.0)
		key_1.finger != key_2.finger && (key_diff *= 1.5)
		key_1.row != key_2.row && (key_diff *= 1.25)

		key_diff ^= settings.keep_familiar
		
		freq = letter_freqs[[char]]
		freq_total += freq
		key_diff *= freq
		total += key_diff
	end
	return total / freq_total
	# return 1.0
end

function get_char_array(key_objects, letter_freqs, settings)::Vector{Char}
	efforts = Vector{Float64}(undef, 24)
	efforts = [stroke_effort(key, settings) for key in key_objects]
	efforts += rand(Float64, 24) .* 0.01
	letters = sort(collect(letter_freqs), by=x->x[2], rev=true)[1:24]
	letters = [only(letter.first) for letter in letters]
	out = Vector{Char}(undef, 24)
	for letter in letters
		idx = findmin(efforts)[2]
		out[idx] = letter
		efforts[idx] = Inf
	end
	return out
end

function get_ngram_efforts(key_objects, settings)
	# TODO skip mirrored ngrams

	letter_efforts = zeros(Float64, 24)
	for i in 1:24
		letter = [i]
		score = analyze_letter(letter, key_objects, settings)
		letter_efforts[i] = score
	end

	bigram_efforts = zeros(Float64, 24, 24)
	for i in 1:24
		for j in 1:24
			bigram = [i, j]
			score = analyze_bigram(bigram, key_objects, settings)
			bigram_efforts[i, j] = score
		end
	end

	trigram_efforts = zeros(Float64, 24, 24, 24)
	# trigram_efforts = [analyze_trigram([i, j, k], key_objects, settings) for i in 1:24, j in 1:24, k in 1:24]
	for i in 1:24
	# for i in [1:4; 9:12; 17:20]
		for j in 1:24
			for k in 1:24
				trigram = [i, j, k]
				score = analyze_trigram(trigram, key_objects, settings)
				trigram_efforts[i, j, k] = score
			end
		end
	end
	ngram_efforts = (letter_efforts, bigram_efforts, trigram_efforts)
	return ngram_efforts
end

function get_ngram_freqs(settings)
	word_data = get_word_data(settings.langs)
	letter_freqs = get_letter_freqs(word_data)

	letters = sort(collect(letter_freqs), by=x->x[2], rev=true)[1:24]
	letters = [only(letter.first) for letter in letters]
	bigram_freqs = get_bigram_freqs_v2(word_data, letters, settings)
	trigram_freqs = get_trigram_freqs(word_data, letters, settings)

	ngram_freqs = (letter_freqs, bigram_freqs, trigram_freqs)
	return ngram_freqs
end

function score_layout!(layout, ngram_freqs, ngram_efforts, key_objects::Tuple, settings)::Float64

	letter_freqs, bigram_freqs, trigram_freqs = ngram_freqs
	letter_efforts, bigram_efforts, trigram_efforts = ngram_efforts
	
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_load = get_finger_load(char_key_dict, letter_freqs, key_objects, settings)
	
	letter_score = evaluate_letters(letter_freqs, letter_efforts, char_key_dict)
	bigram_score = evaluate_bigrams(bigram_freqs, bigram_efforts, char_key_dict)
	# trigram_score = evaluate_trigrams(trigram_freqs, trigram_efforts, char_key_dict)

	# score::Float64 = (letter_score + bigram_score + trigram_score) * finger_load / 3
	score::Float64 = (letter_score + bigram_score) * finger_load
	layout.score = score
	return score
end

function inspect_layout(layout::Layout, key_objects, letter_freqs, settings)
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_usage = zeros(Float64, 8)
	for char in layout.layout_chars
		key::Key = key_objects[char_key_dict[char][1]]
		i = key.finger
		if key.hand
			i = 4 + i
		else
			i = 5 - i
		end
		finger_usage[i] += letter_freqs[[char]]
	end

	for (i, finger) in enumerate(finger_usage)
		print(string(Int(round(100 * finger)), pad=2), " ")
		if i == 4
			print(" ")
		end
	end
	println("")
end

function optimize_layout(settings)

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

	ngram_efforts = get_ngram_efforts(key_objects, settings)
	ngram_freqs = get_ngram_freqs(settings)

	layouts = []
	for _ in 1:settings.initial_states
		chars = get_char_array(key_objects, ngram_freqs[1], settings)
		layout = Layout(chars, Inf)
		normalize_vowels!(layout, settings.vowel_side)
		score_layout!(layout, ngram_freqs, ngram_efforts, key_objects, settings)
		push!(layouts, layout)
	end
	sort!(layouts, by=layout->layout.score, rev=false)
	last_best_layout = layouts[1]
	iter = settings.iterations
	count = 0
	t = time()
	for i in 1:iter
		layouts_copy = deepcopy(layouts)
		for layout in layouts_copy
			new_layouts = []
			while length(new_layouts) < 32
				tmp_layout = deepcopy(layout)
				swap_keys!(tmp_layout)
				normalize_vowels!(tmp_layout, settings.vowel_side)
				layout.layout_chars == tmp_layout.layout_chars && continue  # XXX
				score_layout!(tmp_layout, ngram_freqs, ngram_efforts, key_objects, settings)
				count += 1
				push!(new_layouts, tmp_layout)
			end
			sort!(new_layouts, by=layout->layout.score, rev=false)
			new_layouts = discard_bad_layouts!(new_layouts, 32.0, 4.0)
			append!(layouts, new_layouts)
		end
		sort!(layouts, by=layout->layout.score, rev=false)
		layouts = discard_bad_layouts!(layouts, 128.0, 4.0)
		best_layout_so_far = layouts[1]
		if best_layout_so_far.layout_chars != last_best_layout.layout_chars
			println("$i / $iter")
			print_layout(best_layout_so_far)
			# score = round(best_layout_so_far.score, digits=3)
			# println("Score: $score")
			inspect_layout(best_layout_so_far, key_objects, ngram_freqs[1], settings)
			print("\n")
		end
		last_best_layout = best_layout_so_far
	end
	speed = round(Int, count/(time()-t))
	println("Speed: ", speed, " layouts/s")
	print("\n")
end