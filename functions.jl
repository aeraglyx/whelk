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
	middle_string = "  "
	println(join(chars[1:5],   ' '), middle_string, join(chars[6:10],  ' '))
	println(join(chars[11:15], ' '), middle_string, join(chars[16:20], ' '))
	println(join(chars[21:25], ' '), middle_string, "' ", chars[26], " , . ~")
end

function swap_keys!(layout::Layout)
	chars = layout.layout_chars
	n::UInt8 = rand(1:8)
	for _ in 1:n
		rnd1::UInt8 = rand(1:26)
		rnd2::UInt8 = rand(1:26)
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
	char_key_dict::Dict{Char, UInt8} = Dict(layout_chars[i] => i for i in 1:26)
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
	letter_freqs = Dict(sort(collect(letter_freqs), by=x->x[2], rev=true)[1:26])
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

function stroke_effort(key, settings)::Float64
	stroke_effort::Float64 = 1.0 / settings.finger_strengths[key.finger]

	x = key.offset.x
	y = key.offset.y
	displacement = settings.lateral * x * x + y * y

	stroke_effort *= (1.0 + displacement * settings.prefer_home)

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
		finger_diff = key_2.finger - key_1.finger

		x = key_2.offset.x - key_1.offset.x
		y = key_2.offset.y - key_1.offset.y
		displacement = settings.lateral * x * x + y * y

		if finger_diff == 0
			# same finger
			effort *= 1.0 + settings.sfb * displacement
			
			# up/down
			y < 0 && (effort *= settings.top_to_bottom)
			y > 0 && (effort /= settings.top_to_bottom)
		else
			# 1.0 for neighboring fingers and slowly decaying
			dependence = 2.0 ^ ((1 - abs(finger_diff)) * settings.independence)

			if y != 0
				# scissor
				effort *= 1.0 + settings.scissor * displacement * dependence
			end

			# rolls
			finger_diff < 0 && (effort *= settings.inroll)
			finger_diff > 0 && (effort /= settings.inroll)
		end

		effort *= settings.one_hand
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

function get_finger_load(char_key_dict, letter_freqs, key_objects, settings)::Float64

	finger_load::Vector{Float64} = zeros(8)
	sum_thingy = sum(1 ./ settings.finger_strengths)
	for (char, key_idx) in char_key_dict
		key = key_objects[key_idx]
		finger_idx = key.hand ? 4 + key.finger : 5 - key.finger
		strength = settings.finger_strengths[key.finger]
		finger_load[finger_idx] += letter_freqs[[char]] / strength * sum_thingy
	end

	balance = settings.enforce_balance
	# *2 is like ^2 for the original finger loads
	return 2 ^ (balance * sum(abs.(log2.(finger_load) .* 2)) / 8)
end

function get_char_array(key_objects, letter_freqs, settings)::Vector{Char}
	efforts = Vector{Float64}(undef, 26)
	efforts = [stroke_effort(key, settings) for key in key_objects]
	efforts += rand(Float64, 26) .* 0.01
	letters = sort(collect(letter_freqs), by=x->x[2], rev=true)[1:26]
	letters = [only(letter.first) for letter in letters]
	out = Vector{Char}(undef, 26)
	for letter in letters
		idx = findmin(efforts)[2]
		out[idx] = letter
		efforts[idx] = Inf
	end
	return out
end

function get_letter_efforts(key_objects, settings)
	n = length(key_objects)
	letter_efforts = zeros(Float64, n)
	for i in 1:n
		letter = [i]
		score = analyze_letter(letter, key_objects, settings)
		letter_efforts[i] = score
	end
	return letter_efforts
end

function get_bigram_efforts(key_objects, settings)
	n = length(key_objects)
	bigram_efforts = zeros(Float64, n, n)
	for i in 1:n
		for j in 1:n
			bigram = [i, j]
			score = analyze_bigram(bigram, key_objects, settings)
			bigram_efforts[i, j] = score
		end
	end
	return bigram_efforts
end

function get_ngram_efforts(key_objects, settings)
	letter_efforts = get_letter_efforts(key_objects, settings)
	bigram_efforts = get_bigram_efforts(key_objects, settings)

	ngram_efforts = (letter_efforts, bigram_efforts)
	return ngram_efforts
end

function get_ngram_freqs(settings)
	word_data = get_word_data(settings.langs)
	letter_freqs = get_letter_freqs(word_data)

	letters = sort(collect(letter_freqs), by=x->x[2], rev=true)[1:26]
	letters = [only(letter.first) for letter in letters]
	bigram_freqs = get_bigram_freqs_v2(word_data, letters, settings)

	ngram_freqs = (letter_freqs, bigram_freqs)
	return ngram_freqs
end

function score_layout!(layout, ngram_freqs, ngram_efforts, key_objects::Tuple, settings)::Float64

	letter_freqs, bigram_freqs = ngram_freqs
	letter_efforts, bigram_efforts = ngram_efforts
	
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_load = get_finger_load(char_key_dict, letter_freqs, key_objects, settings)
	
	letter_score = evaluate_letters(letter_freqs, letter_efforts, char_key_dict)
	bigram_score = evaluate_bigrams(bigram_freqs, bigram_efforts, char_key_dict)

	score::Float64 = (0.0 * letter_score + bigram_score) * finger_load
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
		Key(false, 4, Offset(0.0, 1.0)),
		Key(false, 3, Offset(0.0, 1.0)),
		Key(false, 2, Offset(0.0, 1.0)),
		Key(false, 1, Offset(0.0, 1.0)),
		Key(false, 1, Offset(1.0, 1.0)),
		Key(true,  1, Offset(-1.0, 1.0)),
		Key(true,  1, Offset(0.0, 1.0)),
		Key(true,  2, Offset(0.0, 1.0)),
		Key(true,  3, Offset(0.0, 1.0)),
		Key(true,  4, Offset(0.0, 1.0)),
		Key(false, 4, Offset(0.0, 0.0)),
		Key(false, 3, Offset(0.0, 0.0)),
		Key(false, 2, Offset(0.0, 0.0)),
		Key(false, 1, Offset(0.0, 0.0)),
		Key(false, 1, Offset(1.0, 0.0)),
		Key(true,  1, Offset(-1.0, 0.0)),
		Key(true,  1, Offset(0.0, 0.0)),
		Key(true,  2, Offset(0.0, 0.0)),
		Key(true,  3, Offset(0.0, 0.0)),
		Key(true,  4, Offset(0.0, 0.0)),
		Key(false, 4, Offset(0.0, -1.0)),
		Key(false, 3, Offset(0.0, -1.0)),
		Key(false, 2, Offset(0.0, -1.0)),
		Key(false, 1, Offset(0.0, -1.0)),
		Key(false, 1, Offset(1.0, -1.0)),
		# Key(true , 1, Offset(-1.0, -1.0)),
		Key(true,  1, Offset(0.0, -1.0)),
		# Key(true,  2, Offset(0.0, -1.0)),
		# Key(true,  3, Offset(0.0, -1.0)),
		# Key(true,  4, Offset(0.0, -1.0))
	)

	ngram_efforts = get_ngram_efforts(key_objects, settings)
	ngram_freqs = get_ngram_freqs(settings)

	layouts = []
	for _ in 1:settings.initial_states
		chars = get_char_array(key_objects, ngram_freqs[1], settings)
		layout = Layout(chars, Inf)
		# normalize_vowels!(layout, settings.vowel_side)
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
				# normalize_vowels!(tmp_layout, settings.vowel_side)
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
	speed = round(Int, count / (time() - t))
	println("Speed: ", speed, " layouts/s")
	print("\n")
end