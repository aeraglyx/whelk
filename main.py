from re import I
import time
import random
import copy

from classes import Layout
    
#   02 12 22 32   42 52 62 72
#   01 11 21 31   41 51 61 71
#   00 10 20 30   40 50 60 70

most_frequent = "eatoinsr"

	

def naka_rushton(x, p, g):
	tmp = pow(x / p, g)
	return tmp / (tmp + 1)

def discard_bad_layouts(layouts, pivot, gamma):
	return [layout for i, layout in enumerate(layouts) if naka_rushton(i, pivot, gamma) < random.random()]

def prep_freq_data(freq_file, n):
	
	words = []
	freqs = []
	freq_total = 0

	with open(freq_file) as file:
		for _ in range(n):
			word, freq = file.readline().rstrip().split(" ")
			freq = int(freq)
			freq_total += freq
			words.append(word)
			freqs.append(freq)
	
	freqs = [freq / freq_total for freq in freqs]
	freq_data = [(word, freq) for word, freq in zip(words, freqs)]
	return freq_data

def optimize(layout, data, iter):
	
	# corpus_file = "corpus_03.txt"
	layout.analyze(data)

	# ITERATIONS = 4
	# POOL_SIZE = 32

	layouts = [layout]
	last_best_layout = layout
	for i in range(iter):

		layouts_copy = copy.deepcopy(layouts)
		for layout in layouts_copy:

			new_layouts = []
			while len(new_layouts) < 32:
				tmp_layout = copy.deepcopy(layout)
				tmp_layout.swap_yes()
				if layout.char_map == tmp_layout.char_map:
					continue
				tmp_layout.update()
				tmp_layout.analyze(data)
				new_layouts.append(tmp_layout)

			new_layouts.sort(key=lambda x: x.score, reverse=False)
			new_layouts = discard_bad_layouts(new_layouts, 16, 4)

			layouts.extend(new_layouts)
			# TODO possible dupli
		del layouts_copy

		layouts.sort(key=lambda x: x.score, reverse=False)
		layouts = discard_bad_layouts(layouts, 64, 4)
		print(len(layouts))
		
		best_layout_so_far = layouts[0]
		if best_layout_so_far.char_map != last_best_layout.char_map:
			print("\n", end="")
			print(f"Iteration {str(i + 1).zfill(len(str(iter)))} / {iter}")
			print("Best layout so far:")
			print(best_layout_so_far)
			best_layout_so_far.print_stats()
		last_best_layout = best_layout_so_far

	print("\n", end="")




freq_data = prep_freq_data("en_50k.txt", 1024)

x = """
c w h m  g u p j
s r n t  a e i o
b v l d  f z y k
"""

# print(freq_data)

# print(sum([thing[1] for thing in freq_data]))

def timer(start_time):
	total_time = time.perf_counter() - start_time
	print(f"time: {total_time:.3f} s")


start_time = time.perf_counter()
# corpus_file = "corpus_03.txt"
# with open(corpus_file) as file:
# 	data = file.read()

layout = Layout(x)
optimize(layout, freq_data, 4096)

timer(start_time)