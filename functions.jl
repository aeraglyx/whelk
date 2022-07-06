import Unicode: isletter, normalize
using HTTP



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
	left_chars = chars[[1:4; 9:12; 17:20]]
	vowels = ['a', 'e', 'i', 'y', 'o', 'u']
	n = length(intersect(left_chars, vowels))
	if (!vowel_side && n < 3) || (vowel_side && n > 3)
		layout.layout_chars = mirror_chars(chars)
	end
	# TODO e on one side
	# TODO or better yet, weight vowels by their freq
end

function make_char_dict(layout_chars)
	char_key_dict::Dict{Char, Int} = Dict(layout_chars[i] => i for i in 1:24)
	return char_key_dict
end

function make_char_dict_ref(ref_layout)
	# layout_chars = normalize(string(ref_layout), stripmark=true, casefold=true)
	layout_chars = [only(x) for x in split(ref_layout)]
	char_key_dict::Dict{Char, Int} = Dict(layout_chars[i] => i for i in 1:24)
	char_key_dict = filter(x -> isletter(first(x)), char_key_dict)
	return char_key_dict
end

function get_data(lang)
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

function get_letter_freqs(word_freq_data::Dict{String, Float64}, settings)
	letter_freqs = Dict{Vector{Char}, Float64}()
	for (word, freq) in word_freq_data
		for letter in word  # todo
			if [letter] in keys(letter_freqs)
				letter_freqs[[letter]] += freq
			else
				letter_freqs[[letter]] = freq
			end
		end
	end
	normalize_dict!(letter_freqs)
	return letter_freqs
end

function get_bigram_freqs(word_freq_data::Dict{String, Float64}, settings)
	bigram_freqs = Dict{SubString, Float64}()
	for (word, freq) in word_freq_data
		length(word) < 2 && continue
		for ngram in ngrams_from_word(word, 2)
			if ngram in keys(bigram_freqs)
				bigram_freqs[ngram] += freq
			else
				bigram_freqs[ngram] = freq
			end
		end
	end
	bigram_freqs = normalize_dict!(bigram_freqs)
	bigram_freqs = filter_dict!(bigram_freqs, settings.ngram_quality)
	bigram_freqs = normalize_dict!(bigram_freqs)
	return bigram_freqs
end

function get_trigram_freqs(word_freq_data::Dict{String, Float64}, settings)
	trigram_freqs = Dict{SubString, Float64}()
	for (word, freq) in word_freq_data
		length(word) < 3 && continue
		for ngram in ngrams_from_word(word, 3)
			if ngram in keys(trigram_freqs)
				trigram_freqs[ngram] += freq
			else
				trigram_freqs[ngram] = freq
			end
		end
	end
	trigram_freqs = normalize_dict!(trigram_freqs)
	trigram_freqs = filter_dict!(trigram_freqs, settings.ngram_quality)
	trigram_freqs = normalize_dict!(trigram_freqs)
	return trigram_freqs
end

function stroke_effort(key, settings)::Float64
	stroke_effort::Float64 = 1.0 / settings.finger_strengths[key.finger]
	key.row != 2 && (stroke_effort *= 2.0 ^ settings.home_row)
	stroke_effort *= 2.0 ^ ((key.row - 2.0) * settings.prefer_top_row)
	return stroke_effort
end

function analyze_letter(char, key_objects, settings)::Float64
	key::Key = key_objects[char[1]]
	return stroke_effort(key, settings)
end

function analyze_bigram(bigram, key_objects, settings)::Float64

	key_1::Key = key_objects[bigram[1]]
	key_2::Key = key_objects[bigram[2]]

	trans_effort::Float64 = 1.0
	if key_1.hand == key_2.hand
		finger_diff = key_2.finger - key_1.finger
		if finger_diff == 0
			trans_effort /= settings.sfb
		elseif finger_diff < 0
			trans_effort /= settings.inroll
		elseif finger_diff > 0
			trans_effort /= settings.outroll
		end
		travel = 2.0 ^ (abs(key_1.row - key_2.row) * settings.row_change * 0.5)
		trans_effort *= travel
		trans_effort ^= 2.0 ^ (- finger_diff * settings.independence / 3.0)
	else
		trans_effort /= settings.alter
	end
	return trans_effort
end

function analyze_trigram(trigram, key_objects, settings)::Float64

	# TODO precompute key-key pairs ?
	key_1::Key = key_objects[trigram[1]]
	key_2::Key = key_objects[trigram[2]]
	key_3::Key = key_objects[trigram[3]]
	
	trans_effort::Float64 = 1.0
	if key_1.hand == key_3.hand
		if key_1.hand == key_2.hand
			if (key_1.finger < key_2.finger > key_3.finger) || (key_1.finger > key_2.finger < key_3.finger)
				trans_effort /= settings.redirs
			end
		else
			# alteration
		end
		finger_diff = key_3.finger - key_1.finger
		if finger_diff == 0
			trans_effort /= settings.sfb
		elseif finger_diff < 0
			trans_effort /= settings.inroll
		elseif finger_diff > 0
			trans_effort /= settings.outroll
		end
		travel = 2.0 ^ (abs(key_1.row - key_2.row) * settings.row_change * 0.5)
		trans_effort *= travel
		trans_effort ^= 2.0 ^ (- finger_diff * settings.independence / 3.0)
	else
		trans_effort /= settings.alter
	end
	return trans_effort
end

function evaluate_ngrams(ngram_freqs, ngram_efforts, char_key_dict, letters)::Float64
	total_freq::Float64 = 0.0
	total_score::Float64 = 0.0
	for (ngram, freq) in ngram_freqs
		!issubset(collect(ngram), letters) && continue
		ngram_idx = [char_key_dict[ngram[n]] for n in 1:length(ngram)]
		ngram_score = ngram_efforts[ngram_idx]*freq
		total_freq += freq
		total_score += ngram_score
	end
	return total_score/total_freq
end

function get_finger_load(char_key_dict, letter_data, key_objects, settings)::Float64

	letter_data = sort(collect(letter_data), by=x->x[2], rev=true)
	letter_data = Dict(letter_data[1:24])
	letter_data = Dict(letter => freq / sum(values(letter_data)) for (letter, freq) in letter_data)

	f = Vector{Float64}(undef, 8)
	f = zeros(8)
	for (char, key_idx) in char_key_dict
		key = key_objects[key_idx]
		finger_idx = key.hand ? 4 + key.finger : 5 - key.finger
		# TODO first normalize letter data
		strength = settings.finger_strengths[key.finger]
		sum_thingy = sum(1 ./ settings.finger_strengths)
		f[finger_idx] += letter_data[[char]] / strength * sum_thingy
	end
	b = settings.enforce_balance
	f = 2^(b*sum(abs.(log2.(f)))/8)
	return f
end

function how_hard_to_learn(char_key_dict, key_objects, settings, letter_data)::Float64
	
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
		
		freq = letter_data[[char]]
		freq_total += freq
		key_diff *= freq
		total += key_diff
	end
	return total / freq_total
	# return 1.0
end

function get_char_array(key_objects, letter_data, settings)
	efforts = Vector{Float64}(undef, 24)
	efforts = [stroke_effort(key, settings) for key in key_objects]
	efforts += rand(Float64, 24) .* 0.01
	letters = sort(collect(letter_data), by=x->x[2], rev=true)[1:24]
	letters = [only(letter.first) for letter in letters]
	out = Vector{Char}(undef, 24)
	for letter in letters
		idx = findmin(efforts)[2]
		out[idx] = letter
		efforts[idx] = Inf
	end
	return out
end

function analyze_layout(layout, ngram_freqs, ngram_efforts, key_objects::Tuple, settings)::Float64

	letter_freqs, bigram_freqs, trigram_freqs = ngram_freqs
	letter_efforts, bigram_efforts, trigram_efforts = ngram_efforts
	
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_load = get_finger_load(char_key_dict, letter_freqs, key_objects, settings)
	
	letters = layout.layout_chars

	letter_score = evaluate_ngrams(letter_freqs, letter_efforts, char_key_dict, letters)
	bigram_score = evaluate_ngrams(bigram_freqs, bigram_efforts, char_key_dict, letters)
	trigram_score = evaluate_ngrams(trigram_freqs, trigram_efforts, char_key_dict, letters)

	difficulty = how_hard_to_learn(char_key_dict, key_objects, settings, letter_freqs)

	score::Float64 = (letter_score + bigram_score + trigram_score) * finger_load * difficulty / 3
	layout.score = score
	return score
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
		
	letter_efforts = Dict()
	for i in 1:24
		letter = [i]
		score = analyze_letter(letter, key_objects, settings)
		letter in keys(letter_efforts) && continue
		letter_efforts[letter] = score
	end
	
	bigram_efforts = Dict()
	for i in 1:24
		for j in 1:24
			bigram = [i, j]
			score = analyze_bigram(bigram, key_objects, settings)
			bigram in keys(bigram_efforts) && continue
			bigram_efforts[bigram] = score
		end
	end
	
	trigram_efforts = Dict()
	for i in 1:24
		for j in 1:24
			for k in 1:24
				trigram = [i, j, k]
				score = analyze_trigram(trigram, key_objects, settings)
				trigram in keys(trigram_efforts) && continue
				trigram_efforts[trigram] = score
			end
		end
	end

	ngram_efforts = (letter_efforts, bigram_efforts, trigram_efforts)

	word_data = get_word_data(settings.langs)
	letter_freqs = get_letter_freqs(word_data, settings)
	bigram_freqs = get_bigram_freqs(word_data, settings)
	trigram_freqs = get_trigram_freqs(word_data, settings)
	ngram_freqs = (letter_freqs, bigram_freqs, trigram_freqs)

	# letters = get_char_array(key_objects, letter_data, settings)  # TODO clean up data so it doesnt contain unused chars?

	# layout = Layout(letters, Inf, Vector{Float64}(undef, 8))
	layouts = []
	for _ in 1:settings.initial_states
		chars = get_char_array(key_objects, letter_freqs, settings)
		layout = Layout(chars, Inf, Vector{Float64}(undef, 8))
		normalize_vowels!(layout, settings.vowel_side)
		analyze_layout(layout, ngram_freqs, ngram_efforts, key_objects, settings)
		push!(layouts, layout)
	end
	sort!(layouts, by=layout->layout.score, rev=false)
	count = 0
	last_best_layout = layouts[1]
	iter = settings.iterations
	t = time()
	for i in 1:iter
		layouts_copy = deepcopy(layouts)
		for layout in layouts_copy
			new_layouts = []
			while length(new_layouts) < 32
				tmp_layout = deepcopy(layout)
				swap_keys!(tmp_layout)
				normalize_vowels!(tmp_layout, settings.vowel_side)
				layout.layout_chars == tmp_layout.layout_chars && continue
				analyze_layout(tmp_layout, ngram_freqs, ngram_efforts, key_objects, settings)
				count += 1
				push!(new_layouts, tmp_layout)
			end
			sort!(new_layouts, by=layout->layout.score, rev=false)
			new_layouts = discard_bad_layouts!(new_layouts, 16.0, 4.0)
			append!(layouts, new_layouts)
		end
		sort!(layouts, by=layout->layout.score, rev=false)
		layouts = discard_bad_layouts!(layouts, 64.0, 4.0)
		best_layout_so_far = layouts[1]
		if best_layout_so_far.layout_chars != last_best_layout.layout_chars
			println("$i / $iter")
			print_layout(best_layout_so_far)
			score = round(best_layout_so_far.score, digits=3)
			println("Score: $score")
			print("\n")
		end
		last_best_layout = best_layout_so_far
	end
	speed = round(Int, count/(time()-t))
	println("Speed: $speed layouts/s")
	print("\n")
end