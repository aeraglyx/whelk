from unicodedata import east_asian_width


freq_cs = [
	0.09288,
	0.00822,
	0.00779,
	0.03490,
	0.05396,
	0.00084,
	0.00092,
	0.03247,
	0.07716,
	0.01433,
	0.02894,
	0.03802,
	0.02446,
	0.06475,
	0.06719,
	0.01906,
	0.00091,
	0.05179,
	0.05900,
	0.05733,
	0.02409,
	0.05344,
	0.00016,
	0.00027,
	0.02038,
	0.02320]

freq_en = [
	0.08087,
	0.01493,
	0.02781,
	0.04253,
	0.12700,
	0.02228,
	0.02015,
	0.06094,
	0.06966,
	0.00153,
	0.00772,
	0.04094,
	0.02587,
	0.06749,
	0.07507,
	0.01929,
	0.00096,
	0.05987,
	0.06234,
	0.09056,
	0.02758,
	0.00978,
	0.02360,
	0.00150,
	0.01974,
	0.00074]

abc = [
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z"]

mix = 0.25
freq_mixed = [(1.0 - mix) * en + mix * cs for en, cs in zip(freq_en, freq_cs)]
# print(freq_mixed)
# print(sum(freq_cs))


sorted = {abc: freq_mixed for freq_mixed, abc in sorted(zip(freq_mixed, abc))}

print(f"{mix = }")

for char in sorted:
	print(f"{char} - {sorted[char]:.4f}")
# print(sorted)

most_frequent = "eatoinsr"