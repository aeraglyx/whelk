import time
import random
import copy

#  02 12 22 32 42 52 62 72 82 92
#  01 11 21 31 41 51 61 71 81 91
#  00 10 20 30 40 50 60 70 80 90
    
#   02 12 22 32   42 52 62 72
#   01 11 21 31   41 51 61 71
#   00 10 20 30   40 50 60 70

chars = {
	"a": None,
	"b": None,
	"c": None,
	"d": None,
	"e": None,
	"f": None,
	"g": None,
	"h": None,
	"i": None,
	"j": None,
	"k": None,
	"l": None,
	"m": None,
	"n": None,
	"o": None,
	"p": None,
	"q": None,
	"r": None,
	"s": None,
	"t": None,
	"u": None,
	"v": None,
	"w": None,
	"x": None,
	"y": None,
	"z": None
}


class Layout:


	def __init__(self):

		self.row_map = [
			2, 2, 2, 2, 2, 2, 2, 2,
			1, 1, 1, 1, 1, 1, 1, 1,
			0, 0, 0, 0, 0, 0, 0, 0,
			# -1, -1, -1, -1, -1, -1, -1, -1
		]
		self.finger_map = [
			4, 3, 2, 1, 1, 2, 3, 4,
			4, 3, 2, 1, 1, 2, 3, 4,
			4, 3, 2, 1, 1, 2, 3, 4
		]
		self.hand_map = [
			"left", "left", "left", "left", "right", "right", "right", "right",
			"left", "left", "left", "left", "right", "right", "right", "right",
			"left", "left", "left", "left", "right", "right", "right", "right"
		]
		self.char_map = [
			"b", "w", "f", "p", "l", "u", "y", "j",
			"a", "r", "s", "t", "n", "e", "i", "o",
			"z", "v", "c", "d", "h", "g", "m", "k"
		]
		
		self.score = None

		self.update()
	

	def update(self):
		self.char_dict = {}
		for i, char in enumerate(self.char_map):
			if char is not None:
				self.char_dict[char.lower()] = Key(self.hand_map[i], self.finger_map[i], self.row_map[i], self.char_map[i])

	def swap_rnd(self):
		rnd = random.sample(range(0, 23), 2)
		self.char_map[rnd[0]], self.char_map[rnd[1]] = self.char_map[rnd[1]], self.char_map[rnd[0]]
	
	def analyze(self, corpus_file):

		SBF_PENALTY = 1.0
		INWARD_ROLL = -0.5
		OUTWARD_ROLL = 0.0

		#  0 - thumb
		#  1 - index
		#  2 - middle
		#  3 - ring
		#  4 - little

		start_time = time.perf_counter()
		
		with open(corpus_file) as file:

			char_count = 0

			key_prev = None
			score = 0.0
			same_hand_streak = 0
			same_finger_streak = 0
			roll_streak = 0

			while True:

				char = file.read(1).lower()
				if not char:
					break
				
				char_count += 1
				
				key = self.char_dict[char] if char in self.char_dict else None
				
				if not key:
					continue

				if not key_prev:
					key_prev = key
					continue

				if key.hand == key_prev.hand:
					# same hand
					same_hand_streak += 1
					
					if key.finger == key_prev.finger:
						# SFB
						score += SBF_PENALTY
					
					if key.finger < key_prev.finger:
						# inward roll
						roll_streak += 1
						score += INWARD_ROLL
					if key.finger > key_prev.finger:
						# outward roll
						roll_streak += 1
						score += OUTWARD_ROLL
					
					# else:
					# 	roll_streak += 1
					# 	if key.finger < key_prev.finger:
					# 		# inward roll
					# 		score += INWARD_ROLL

				else:
					# alternating
					#  streak ended - penalty
					score += 0.1 * same_hand_streak ** 2
					same_hand_streak = 1

				key_prev = key
		
		total_time = time.perf_counter() - start_time

		self.score = score / char_count
		
		print("\n", end="")
		print(self)
		print("\n", end="")
		print(f"corpus: {corpus_file}")
		print(f"number of chars: {char_count}")
		print("\n", end="")
		print(f"score: {score / char_count:.6f}")
		print(f"time: {total_time:.3f} s")
		print("\n", end="")


	def mirror(self):
		pass


	def debug(self):
		for key in self.char_map:
			print(key.finger)


	def __str__(self):
		string = ""
		for i, char in enumerate(self.char_map):
			to_add = '-' if char == None else char
			string += to_add
			if i == 7 or i == 15:
				string += "\n"
			elif i % 8 == 3:
				string += "  "
			else:
				string += " "
		return string

				

class Key:
	def __init__(self, hand, finger, row, char):
		self.hand = hand
		self.finger = finger
		self.row = row
		self.char = char

class Letter:
	def __init__(self, char, freq):
		self.char = char
		self.freq = freq





corpus_file = "corpus_03.txt"

layout = Layout()
# print(layout)
layout.analyze(corpus_file)

while True:
	tmp_layout = copy.deepcopy(layout)
	tmp_layout.swap_rnd()
	tmp_layout.update()
	tmp_layout.analyze(corpus_file)
	if tmp_layout.score < layout.score:
		layout = tmp_layout
	else:
		del tmp_layout
	print(layout)