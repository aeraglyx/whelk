function get_letter_freqs(word_freq_data::Dict{String, Float64})
	letter_freqs = Dict{Char, Float64}()
	for (word, freq) in word_freq_data
		for letter in word
			letter_freqs[letter] = get!(letter_freqs, letter, 0.0) + freq
		end
	end
	letter_freqs = Dict(sort(collect(letter_freqs), by=x->x[2], rev=true)[1:26])
	normalize_dict!(letter_freqs)
	return letter_freqs
end

function ngrams_from_word(word, n)
	return [view(word, i:i+n-1) for i = 1:length(word)-n+1]
end

function get_bigram_freqs_from_words(word_freq_data::Dict{String, Float64}, letters, skipgram_weight)
	bigram_freqs = Dict{NTuple{2, Char}, Float64}()

	for (word, freq) in word_freq_data
		word_length = length(word)
		word_length < 2 && continue

		for n in 2:word_length
			for ngram in ngrams_from_word(word, n)
				bigram = Tuple([ngram[begin], ngram[end]])
				!issubset(collect(bigram), letters) && continue
				weight = skipgram_weight ^ (n - 1)
				bigram_freqs[bigram] = get!(bigram_freqs, bigram, 0.0) + freq * weight
			end
		end
	end

	normalize_dict!(bigram_freqs)
	return bigram_freqs
end

function get_bigram_freqs_from_spaces(word_freq_data::Dict{String, Float64}, letters, skipgram_weight)
	start_freqs = Dict{Char, Float64}()
	end_freqs = Dict{Char, Float64}()

	for (word, freq) in word_freq_data
		word_length = length(word)

		for n1 in 1:word_length
			n2 = word_length - n1 + 1
			l1 = word[n1]
			l2 = word[n2]
			weight = skipgram_weight ^ (n1 - 1)
			start_freqs[l1] = get!(start_freqs, l1, 0.0) + freq * weight
			end_freqs[l2] = get!(end_freqs, l2, 0.0) + freq * weight
		end
	end

	bigram_freqs = Dict{NTuple{2, Char}, Float64}()
	for (start_letter, start_freq) in start_freqs
		for (end_letter, end_freq) in end_freqs
			bigram_freqs[Tuple([start_letter, end_letter])] = start_freq * end_freq
		end
	end

	normalize_dict!(bigram_freqs)
	return bigram_freqs
end

function get_bigram_freqs(word_freq_data::Dict{String, Float64}, letters, cfg)
	freqs_from_words = get_bigram_freqs_from_words(word_freq_data, letters, cfg.skipgram_weight)
	freqs_from_spaces = get_bigram_freqs_from_spaces(word_freq_data, letters, cfg.skipgram_weight)

	typical_word_length = 5
	space_weight = 0.75 * cfg.skipgram_weight / (typical_word_length + 1)

	bigram_freqs = mergewith(
		(v1, v2) -> (1.0 - space_weight) * v1 + space_weight * v2,
		freqs_from_words,
		freqs_from_spaces
	)

	bigrams_total = length(bigram_freqs)
	bigram_freqs = filter_dict(bigram_freqs, cfg.bigram_quality)
	println(length(bigram_freqs), "/", bigrams_total, " bigrams")

	normalize_dict!(bigram_freqs)
	return bigram_freqs
end
