import Unicode: isletter, normalize



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

function get_word_data(lang_prefs::Dict{String, Float64}, n::Int)::Dict{String, Float64}
	datax = Dict{String, Float64}()
	for (lang, weight) in lang_prefs
		data_filename = "freq_data/" * lang * "_50k.txt"
		data = Vector{Tuple{String, Int64}}(undef, n)
		freq_total::UInt = 0
		open(data_filename, "r") do file
			for i in 1:n
				word, freq = split(readline(file), ' ')
				word = normalize(string(word), stripmark=true, casefold=true)
				word = filter(isletter, word)
				freq = parse(UInt, freq)
				freq_total += freq
				data[i] = (word, freq)
			end
		end
		mergewith!(+, datax, Dict(word => freq * weight / freq_total for (word, freq) in data))
	end
	return datax
end

# function ngram(s::AbstractString, n::Int)
# 	[SubString(s, i:i+n-1) for i = 1:length(s)-n+1]
# end

function get_ngram_data(word_freq_data::Dict{String, Float64}, n::Int)
	bigram_data = Dict{SubString, Float64}()
	for (word, freq) in word_freq_data
		ngrams = [SubString(word, i:i+n-1) for i = 1:length(word)-n+1]
		# ngrams = ngram(word, 1)
		for ngram in ngrams
			# datax[ngram] = ngram in datax ? datax[ngram] + freq : freq
			if ngram in keys(bigram_data)
				bigram_data[ngram] += freq
			else
				bigram_data[ngram] = freq
			end
		end
	freq_total = sum(values(bigram_data))
	bigram_data = Dict(ngram => freq / freq_total for (ngram, freq) in bigram_data)
	end
	return bigram_data
end

function analyze_letter(char::SubString, char_key_dict)::Float64
	if only(char) == 'x' || only(char) == 'q'
		return 0.0
	end
	key::Key = char_key_dict[only(char)]
	finger_strengths = (1.2, 1.0, 1.5, 2.3)
	stroke_effort::Float64 = finger_strengths[key.finger]
	if key.row != 2
		stroke_effort *= 1.5
	end
	return stroke_effort
end

function analyze_bigram(bigram::SubString, char_key_dict)

	if only(bigram[1]) == 'x' || only(bigram[1]) == 'q' || only(bigram[2]) == 'x' || only(bigram[2]) == 'q'
		return 0.0
	end

	# TODO precompute key-key pairs ?
	
	SFB_PENALTY ::Float64 = 4.0
	INWARD_ROLL ::Float64 = 0.7
	OUTWARD_ROLL::Float64 = 1.2
	
	key_1::Key = char_key_dict[bigram[1]]
	key_2::Key = char_key_dict[bigram[2]]
	
	finger_strengths = (1.2, 1.0, 1.5, 2.3)
	trans_effort::Float64 = (finger_strengths[key_1.finger] + finger_strengths[key_2.finger]) * 0.5

	if key_1.hand == key_2.hand
		if key_1.finger == key_2.finger
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



function analyze_ngrams(ngram_data, analyze_ngram, char_key_dict)::Float64
	score::Float64 = 0.0
	for (ngram, freq) in ngram_data
		ngram_score = analyze_ngram(ngram, char_key_dict)
		score += ngram_score * freq
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



function analyze_layout(layout, letter_data, bigram_data)
	char_key_dict = layout.char_key_dict
	# println(letter_data)
	score_letters = analyze_ngrams(letter_data, analyze_letter, char_key_dict)
	# println(score_letters)
	score_bigrams = analyze_ngrams(bigram_data, analyze_bigram, char_key_dict)
	# println(score_bigrams)
	score::Float64 = score_letters * 0.5 + score_bigrams * 0.5
	layout.score = score
	println(score)
end


function optimize_layout(layout::Layout, lang_prefs, iter::Int = 64, data_length::Int = 4096)
	word_data = get_word_data(lang_prefs, data_length)
	letter_data = get_ngram_data(word_data, 1)
	bigram_data = get_ngram_data(word_data, 2)
	analyze_layout(layout, letter_data, bigram_data)
	layouts = [layout]
	last_best_layout = layout
	for i in 1:iter
		layouts_copy = deepcopy(layouts)
		for layout in layouts_copy
			new_layouts = []
			while length(new_layouts) < 32
				tmp_layout = deepcopy(layout)
				# swap_keys!(tmp_layout)  # TODO 
				if layout.char_key_dict == tmp_layout.char_key_dict
					continue
				end
				analyze_layout(tmp_layout, letter_data, bigram_data)
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
	@time optimize_layout(layout, lang_prefs, 1, 1024)

end

main()