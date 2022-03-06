import string


def print_frequencies(dict):

	BAR_WIDTH = 32
	DECIMALS = 6

	max_freq = max(dict.values())
	for char in sorted(dict, key=dict.get, reverse=True):
		
		match char:
			case " ":
				char_print = "SPC"
			case "\n":
				char_print = "ENT"
			case "\t":
				char_print = "TAB"
			case _:
				char_print = f" {char.upper()} "
		
		x_count = 1 + int(dict[char] / max_freq * (BAR_WIDTH - 1))
		print(f"{char_print} |  {dict[char]:.{DECIMALS}f}  |  {'X' * x_count}")


def get_char_freq_from_corpus(corpus_file, chars_to_check=None):

	if chars_to_check:
		letters = {char: 0 for char in chars_to_check}
	else:
		letters = {}
	
	letters_total = 0
	with open(corpus_file) as corpus:
		
		while True:
			char = corpus.read(1).lower()
			if not char:
				break

			if char in letters:
				letters[char] += 1
				letters_total += 1
			elif not chars_to_check:
				letters[char] = 1
	
	#  normalize, so sum = 1.0
	for char in letters:
		letters[char] /= letters_total
	
	return letters


def get_weird_chars_from_corpus(corpus_file):
	expected_chars = list(string.ascii_lowercase + string.ascii_uppercase + string.digits)
	weird_chars = set()
	with open(corpus_file) as corpus:
		while True:
			char = corpus.read(1)
			if not char:
				break
			if char not in expected_chars:
				if char not in weird_chars:
					weird_chars.add(char)
	print(f"Weird letter found in \"{corpus_file}\":\n{weird_chars}")


corpus = "corpus.txt"

print("\n")
chars_to_check = string.ascii_lowercase + string.digits + string.punctuation
freq = get_char_freq_from_corpus(corpus)

print_frequencies(freq)
print("\n")