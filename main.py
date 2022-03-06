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

		row = [
			2, 2, 2, 2, 2, 2, 2, 2,
			1, 1, 1, 1, 1, 1, 1, 1,
			0, 0, 0, 0, 0, 0, 0, 0,
			# -1, -1, -1, -1, -1, -1, -1, -1
		]
		
		finger = [
			4, 3, 2, 1, 1, 2, 3, 4,
			4, 3, 2, 1, 1, 2, 3, 4,
			4, 3, 2, 1, 1, 2, 3, 4
		]

		hand = [
			"left", "left", "left", "left", "right", "right", "right", "right",
			"left", "left", "left", "left", "right", "right", "right", "right",
			"left", "left", "left", "left", "right", "right", "right", "right"
		]

		char = [
			None, None, None, None, None, None, None, None,
			None, None, "a", None, None, None, None, None,
			None, None, None, None, None, None, None, None
		]

		self.keys = [Key(hand, finger, row, char) for hand, finger, row, char in zip(hand, finger, row, char)]
		
	
	def analyze(self, corpus_file):

		SBF_PENALTY = 1.0
		INWARD_ROLL = -0.5
		OUTWARD_ROLL = 0.0

		#  0 - thumb
		#  1 - index
		#  2 - middle
		#  3 - ring
		#  4 - little
		
		with open(corpus_file) as file:

			key_prev = None
			score = 0.0
			same_hand_streak = 0
			same_finger_streak = 0

			while True:

				char = file.read(1)
				if not char:
					break

				key = next((key for key in self.keys if key.char == char), None)
				
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
				print(score)


	def mirror(self):
		pass


	def debug(self):
		for key in self.keys:
			print(key.finger)


	# def print_layout(self):
	# 	for i, key in enumerate(self.keys):
	# 		if i % 8 == 7:
	# 			end = "\n"
	# 		elif i % 8 == 3:
	# 			end = "  "
	# 		else:
	# 			end = " "
	# 		print(f"{'-' if key.char == None else key.char}", end=end)
	# 	print("\n", end="")


	def __str__(self):

		string = ""
		
		for i, key in enumerate(self.keys):

			to_add = '-' if key.char == None else key.char
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

# a = Letter(char="a", freq=0.082)

# layout.k00.letter = a

# layout.print_layout()

layout = Layout()
print(layout)

corpus_file = "corpus.txt"
layout.analyze(corpus_file)

# print("\n", end="")
# layout.print_layout()




# "A", 0.08200
# "B", 0.01500
# "C", 0.02700
# "D", 0.04300
# "E", 0.13000
# "F", 0.02200
# "G", 0.02000
# "H", 0.06200
# "I", 0.06900
# "J", 0.01500
# "K", 0.07800
# "L", 0.04100
# "M", 0.02500
# "N", 0.06700
# "O", 0.07800
# "P", 0.01900
# "Q", 0.00096
# "R", 0.05900
# "S", 0.06200
# "T", 0.09600
# "U", 0.02700
# "V", 0.00970
# "W", 0.02400
# "X", 0.00150
# "Y", 0.02000
# "Z", 0.00078


# a	0.08087		0.09288
# b	0.01493		0.00822
# c	0.02781		0.00779
# d	0.04253		0.03490
# e	0.12700		0.05396
# f	0.02228		0.00084
# g	0.02015		0.00092
# h	0.06094		0.03247
# i	0.06966		0.07716
# j	0.00153		0.01433
# k	0.00772		0.02894
# l	0.04094		0.03802
# m	0.02587		0.02446
# n	0.06749		0.06475
# o	0.07507		0.06719
# p	0.01929		0.01906
# q	0.00096		0.00091
# r	0.05987		0.05179
# s	0.06234		0.05900
# t	0.09056		0.05733
# u	0.02758		0.02409
# v	0.00978		0.05344
# w	0.02360		0.00016
# x	0.00150		0.00027
# y	0.01974		0.02038
# z	0.00074		0.02320


# https://en.wikipedia.org/wiki/Letter_frequency

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