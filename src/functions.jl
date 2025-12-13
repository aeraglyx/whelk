using TOML
using HTTP
using Random

include("./utils.jl")
include("./data.jl")
include("./freqs.jl")
include("./efforts.jl")


function get_config(file)
	dict = TOML.parsefile(file)
	config = (; (Symbol(k) => v for (k, v) in dict)...)
	return config
end


function naka_rushton(x::Float64, p::Float64, g::Float64)::Float64
	tmp = (x / p) ^ g
	return tmp / (tmp + 1.0)
end


function survives(i, pivot, g)
	i = max(0, i - 4)  # so it never deletes the best 4
	survival_probability = naka_rushton(convert(Float64, i), pivot, g)
	return survival_probability < rand(Float64)
end


function discard_bad_layouts!(layouts, pivot::Float64, g::Float64)
	# TODO: put normalization outside or hardcode g
	normalization = g * sin(pi / g) / pi
	pivot *= normalization  # so pivot later matches population
	return [x for (i, x) in enumerate(layouts) if survives(i, pivot, g)]
end


function swap_keys!(layout::Layout, ids_to_swap)
	chars = layout.layout_chars
	k::UInt8 = rand(1:5)
	for _ in 1:k
		rnd1::UInt8 = rand(ids_to_swap)
		rnd2::UInt8 = rand(ids_to_swap)
		chars[rnd1], chars[rnd2] = chars[rnd2], chars[rnd1]
	end
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
	# TODO: weight vowels by their freq
end


function make_char_dict(layout_chars)::Dict{Char, UInt8}
	char_key_dict::Dict{Char, UInt8} = Dict(layout_chars[i] => i for i in eachindex(layout_chars))
	return char_key_dict
end


function evaluate_letters(letter_freqs, letter_efforts, char_key_dict)::Float64
	total_score::Float64 = 0.0
	for (ngram, freq) in letter_freqs
		current_score = letter_efforts[char_key_dict[ngram[1]]] * freq
		total_score += current_score
	end
	return total_score
end


function evaluate_bigrams(bigram_freqs, bigram_efforts, char_key_dict)::Float64
	total_score::Float64 = 0.0
	for (ngram, freq) in bigram_freqs
		current_score = bigram_efforts[char_key_dict[ngram[1]], char_key_dict[ngram[2]]] * freq
		total_score += current_score
	end
	return total_score
end


function get_finger_usage(char_key_dict, letter_freqs, key_objects)::Vector{Float64}
	finger_usage::Vector{Float64} = zeros(10)
	for (char, key_idx) in char_key_dict
		key = key_objects[key_idx]
		finger_id = key.hand ? 5 + key.finger : 6 - key.finger
		finger_usage[finger_id] += letter_freqs[char]
	end
	return finger_usage
end


function get_finger_load(char_key_dict, letter_freqs, key_objects, cfg)::Float64
	finger_usage = get_finger_usage(char_key_dict, letter_freqs, key_objects)
    finger_strengths = cfg.finger_strengths[[5:-1:1; 1:5]]
    finger_strengths ./= sum(finger_strengths)
	finger_load = finger_usage ./ finger_strengths
    return 2 ^ (cfg.enforce_balance * sum(abs.(log2.(finger_load))) / 10)
end


function get_ids_to_swap(letters)::Vector{Int}
	letters = collect(letters)
	letters = filter(!isspace, letters)
	letters = replace(letters, '␣' => ' ')
	ids = [i for (i, letter) in enumerate(letters) if letter == '~']
	return ids
end


function get_char_array_rnd(key_objects, letter_freqs, letters_fixed)::Vector{Char}
    letters_fixed = collect(letters_fixed)
    letters_fixed = filter(!isspace, letters_fixed)
    letters_fixed = replace(letters_fixed, '␣' => ' ')
	ids_to_swap = [i for (i, letter) in enumerate(letters_fixed) if letter == '~']

	letters_shuffled = filter(((k, v),) -> !(k in letters_fixed), letter_freqs)
	n_shuffled = length(ids_to_swap)
	letters_shuffled = sort(collect(letters_shuffled), by=x->x[2], rev=true)[1:n_shuffled]
	letters_shuffled = [only(letter.first) for letter in letters_shuffled]
	letters_shuffled = shuffle(letters_shuffled)

	letters::Vector{Char} = []
	for i in eachindex(key_objects)
		if i in ids_to_swap
			append!(letters, pop!(letters_shuffled))
		else
			append!(letters, letters_fixed[i])
		end
	end
	return letters
end


function get_ngram_freqs(word_data, cfg)
	letter_freqs = get_letter_freqs(word_data)

	letters = [only(letter.first) for letter in letter_freqs]
	bigram_freqs = get_bigram_freqs(word_data, letters, cfg)

	ngram_freqs = (letter_freqs, bigram_freqs)
	return ngram_freqs
end


function score_layout!(layout, ngram_freqs, ngram_efforts, key_objects::Tuple, cfg)::Float64

	letter_freqs, bigram_freqs = ngram_freqs
	letter_efforts, bigram_efforts = ngram_efforts

	char_key_dict = make_char_dict(layout.layout_chars)
	finger_load = get_finger_load(char_key_dict, letter_freqs, key_objects, cfg)

	# letter_score = evaluate_letters(letter_freqs, letter_efforts, char_key_dict)
	bigram_score = evaluate_bigrams(bigram_freqs, bigram_efforts, char_key_dict)

	layout.score = bigram_score * finger_load
end


function print_layout(layout::Layout)
	chars = layout.layout_chars
	chars = replace(chars, ' ' => '␣')
	println(join(chars[[ 1: 5;  6:10]], " "))
	println(join(chars[[11:15; 16:20]], " "))
	println(join(chars[[21:25; 26:30]], " "))
	println("      ", chars[31], "     ", chars[32])
end


function inspect_layout(layout::Layout, key_objects, letter_freqs)
	char_key_dict = make_char_dict(layout.layout_chars)
	finger_usage = get_finger_usage(char_key_dict, letter_freqs, key_objects)
	finger_usage_str = string.(Int.(round.(100 * finger_usage)), pad=2)
	println(join(finger_usage_str[1:4], " "), " ", join(finger_usage_str[7:10], " "))
	println("         ", finger_usage_str[5], " ", finger_usage_str[6])
	println("")
end


function optimize_layout_single(data, cfg)

	key_objects, ngram_freqs, ngram_efforts, ids_to_swap = data

	layouts::Vector{Layout} = []
	for _ in 1:cfg.population
		chars = get_char_array_rnd(key_objects, ngram_freqs[1], cfg.letters)
		layout = Layout(chars, Inf)
		# normalize_vowels!(layout, cfg.vowel_side)
		score_layout!(layout, ngram_freqs, ngram_efforts, key_objects, cfg)
		push!(layouts, layout)
	end

	sort!(layouts, by=layout->layout.score, rev=false)
	last_best_layout::Layout = layouts[1]
	last_improvement_gen = 1
	count = 0
	t = time()

	for i in 1:cfg.generations
		for layout in layouts[:]
			child_layouts::Vector{Layout} = []
			# TODO: fewer children for bad parents?
			while length(child_layouts) < cfg.children
				tmp_layout = deepcopy(layout)
				swap_keys!(tmp_layout, ids_to_swap)
				# normalize_vowels!(tmp_layout, cfg.vowel_side)
				layout.layout_chars == tmp_layout.layout_chars && continue  # XXX
				score_layout!(tmp_layout, ngram_freqs, ngram_efforts, key_objects, cfg)
				count += 1
				push!(child_layouts, tmp_layout)
			end
			sort!(child_layouts, by=layout->layout.score, rev=false)
			child_layouts = discard_bad_layouts!(child_layouts, convert(Float64, cfg.children), 2.0)
			append!(layouts, child_layouts)
		end
		sort!(layouts, by=layout->layout.score, rev=false)
		layouts = discard_bad_layouts!(layouts, convert(Float64, cfg.population), 2.0)
		if layouts[1] != last_best_layout
			last_improvement_gen = i
		end
		last_best_layout = layouts[1]
		# last_best_effort = round(last_best_layout.score, digits=2)
		# print("\r$i/$(cfg.generations) | effort: $last_best_effort")
		if i - last_improvement_gen > 64
			break
		end
	end

	speed = round(Int, count / (time() - t))
	return last_best_layout, speed
end


function optimize_layout(cfg)

	key_objects = (
		Key(false, 5, Offset(0.0, 1.0)),
		Key(false, 4, Offset(0.0, 1.0)),
		Key(false, 3, Offset(0.0, 1.0)),
		Key(false, 2, Offset(0.0, 1.0)),
		Key(false, 2, Offset(1.0, 1.0)),
		Key(true,  2, Offset(-1.0, 1.0)),
		Key(true,  2, Offset(0.0, 1.0)),
		Key(true,  3, Offset(0.0, 1.0)),
		Key(true,  4, Offset(0.0, 1.0)),
		Key(true,  5, Offset(0.0, 1.0)),

		Key(false, 5, Offset(0.0, 0.0)),
		Key(false, 4, Offset(0.0, 0.0)),
		Key(false, 3, Offset(0.0, 0.0)),
		Key(false, 2, Offset(0.0, 0.0)),
		Key(false, 2, Offset(1.0, 0.0)),
		Key(true,  2, Offset(-1.0, 0.0)),
		Key(true,  2, Offset(0.0, 0.0)),
		Key(true,  3, Offset(0.0, 0.0)),
		Key(true,  4, Offset(0.0, 0.0)),
		Key(true,  5, Offset(0.0, 0.0)),

		Key(false, 5, Offset(0.0, -1.0)),
		Key(false, 4, Offset(0.0, -1.0)),
		Key(false, 3, Offset(0.0, -1.0)),
		Key(false, 2, Offset(0.0, -1.0)),
		Key(false, 2, Offset(1.0, -1.0)),
		Key(true , 2, Offset(-1.0, -1.0)),
		Key(true,  2, Offset(0.0, -1.0)),
		Key(true,  3, Offset(0.0, -1.0)),
		Key(true,  4, Offset(0.0, -1.0)),
		Key(true,  5, Offset(0.0, -1.0)),

		Key(false, 1, Offset(0.0, 0.0)),
		Key(true,  1, Offset(0.0, 0.0)),
	)

	@info "initializing..."

	word_data = get_word_data(cfg.langs)
	ngram_freqs = get_ngram_freqs(word_data, cfg)
	ngram_efforts = get_ngram_efforts(key_objects, cfg)
	ids_to_swap = get_ids_to_swap(cfg.letters)

	data = key_objects, ngram_freqs, ngram_efforts, ids_to_swap

	t = time()

	threads_available = Threads.nthreads()

	if threads_available == 1 @warn "using only 1 thread"
	else @info "using $threads_available threads" end

	total = 1:threads_available
	chunks = Iterators.partition(total, cld(length(total), threads_available))

	@info "optimizing layout..."
	tasks = map(chunks) do chunk
		Threads.@spawn optimize_layout_single(data, cfg)
	end

	results = fetch.(tasks)
	layouts, speeds = map(collect, zip(results...))

	sort!(layouts, by=layout->layout.score, rev=false)
	@info "best scores: $(string([round(layout.score, digits=1) for layout in layouts]))"
	best_layout = layouts[1]

	@info "speed: $(sum(speeds)) l/s"
	println("")

	print_layout(best_layout)
	println("")
	# inspect_layout(best_layout, key_objects, ngram_freqs[1])
	# println("")
end
