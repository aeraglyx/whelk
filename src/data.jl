import Unicode: isletter, normalize


function download_lang_file(lang::String, lang_filepath::String)
	url_base = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/"
	url = url_base * lang * "/" * lang * "_50k.txt"
	data = HTTP.request("GET", url).body
	data = strip(String(data))
	open(lang_filepath, "w") do io
		print(io, data)
	end
end


function get_lang_word_data(lang)::String
	lang_filepath = joinpath("data", lang * ".txt")
	!isfile(lang_filepath) && download_lang_file(lang, lang_filepath)

	data::String = ""
	open(lang_filepath) do f
		data = read(f, String)
	end
	return data
end


function normalize_word(word::String)::String
	word = normalize(word, stripmark=true, casefold=true)
	word = filter(isascii, word)
	word = filter(isletter, word)
	return word
end


function substitute_repeat_keys(word::String)::String
	return replace(word, r"(?<=(.))\1" => "@")
end


function get_word_data(langs::Dict{String, Any})::Dict{String, Float64}
	data = Dict{String, Float64}()
	for (lang, weight) in langs
		weight == 0.0 && continue
		data_per_lang = Dict{String, UInt}()
		freq_total::UInt = 0
		data_raw = get_lang_word_data(lang)
		for line in eachline(IOBuffer(data_raw))
			word, freq = split(line, " ")
			word = normalize_word(string(word))
			word = substitute_repeat_keys(word)
			freq = parse(UInt, freq)
			freq_total += freq
			data_per_lang[word] = get!(data_per_lang, word, 0) + freq
		end
		weighted_data = Dict(word => weight * freq / freq_total for (word, freq) in data_per_lang)
		mergewith!(+, data, weighted_data)
	end
	return data
end
