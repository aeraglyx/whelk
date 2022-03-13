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



start_time = time.perf_counter()

corpus_file = "corpus_03.txt"
layout = Layout()
layout.analyze(corpus_file)

ITERATIONS = 128
# POOL_SIZE = 32

layouts = [layout]
last_best_layout = layout
for i in range(ITERATIONS):

	layouts_copy = copy.deepcopy(layouts)
	for layout in layouts_copy:

		new_layouts = []
		while len(new_layouts) < 32:
			tmp_layout = copy.deepcopy(layout)
			tmp_layout.swap_yes()
			if layout.char_map == tmp_layout.char_map:
				continue
			tmp_layout.update()
			tmp_layout.analyze(corpus_file)
			new_layouts.append(tmp_layout)

		new_layouts.sort(key=lambda x: x.score, reverse=False)
		new_layouts = discard_bad_layouts(new_layouts, 16, 4)

		layouts.extend(new_layouts)
		# TODO possible dupli

	layouts.sort(key=lambda x: x.score, reverse=False)
	layouts = discard_bad_layouts(layouts, 64, 4)
	print(len(layouts))
	
	best_layout_so_far = layouts[0]
	if best_layout_so_far.char_map != last_best_layout.char_map:
		print("\n", end="")
		print(f"Iteration {str(i + 1).zfill(len(str(ITERATIONS)))} / {ITERATIONS}")
		print("Best layout so far:")
		print(best_layout_so_far)
		best_layout_so_far.print_stats()
	last_best_layout = best_layout_so_far

print("\n", end="")
total_time = time.perf_counter() - start_time
print(f"time: {total_time:.3f} s")