function letter_effort(key::Key, cfg)::Float64
	effort = 1.0 / cfg.finger_strengths[key.finger]

	x = key.offset.x
	y = key.offset.y
	displacement = cfg.lateral * x * x + y * y

	effort *= (1.0 + displacement * cfg.prefer_home)
	return effort
end


function get_dexterity_integrated(dexterity_map)::Vector{Float64}
	accum = 0.0
	dexterity_integrated = Vector{Float64}(undef, length(dexterity_map))
	for i in eachindex(dexterity_map)
		dexterity_integrated[i] = accum
		if i < 4
			accum += (dexterity_map[i] + dexterity_map[i+1]) * 0.5
		end
	end
	return dexterity_integrated
end


function bigram_effort(key_1::Key, key_2::Key, cfg)::Float64
	effort = 1.0
	if key_1.hand != key_2.hand
		return effort
	end

	finger_diff = key_2.finger - key_1.finger
	x = key_2.offset.x - key_1.offset.x
	y = key_2.offset.y - key_1.offset.y
	displacement = cfg.lateral * x*x + y*y

	if finger_diff == 0
		effort *= 1.0 + cfg.sfb * displacement / cfg.finger_dexterity[key_1.finger]
		y < 0 && (effort *= cfg.top_to_bottom)
		y > 0 && (effort /= cfg.top_to_bottom)
	else
		dexterity_integrated = get_dexterity_integrated(cfg.finger_dexterity)
		bigram_dexterity = abs(dexterity_integrated[key_2.finger] - dexterity_integrated[key_1.finger])
		dependence = 0.5 ^ (bigram_dexterity * cfg.independence)
		y != 0 && (effort *= 1.0 + cfg.scissor * displacement * dependence)
		finger_diff < 0 && (effort *= cfg.inroll)
		finger_diff > 0 && (effort /= cfg.inroll)
	end

	effort *= cfg.one_hand
	return effort
end


function get_letter_efforts(key_objects, cfg)
	n = length(key_objects)
	letter_efforts = zeros(Float64, n)
	for i in 1:n
		effort = letter_effort(key_objects[i], cfg)
		letter_efforts[i] = effort
	end
	return letter_efforts
end


function get_bigram_efforts(key_objects, cfg)
	n = length(key_objects)
	bigram_efforts = zeros(Float64, n, n)
	for i in 1:n
		for j in 1:n
			effort = bigram_effort(key_objects[i], key_objects[j], cfg)
			bigram_efforts[i, j] = effort
		end
	end
	return bigram_efforts
end


function get_ngram_efforts(key_objects, cfg)
	letter_efforts = get_letter_efforts(key_objects, cfg)
	bigram_efforts = get_bigram_efforts(key_objects, cfg)
	ngram_efforts = (letter_efforts, bigram_efforts)
	return ngram_efforts
end
