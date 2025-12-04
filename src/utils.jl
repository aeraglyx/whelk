function normalize_dict!(dict)
	value_total = sum(values(dict))
	for (key, value) in dict
		dict[key] /= value_total
	end
end


function filter_dict(dict, threshold)
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