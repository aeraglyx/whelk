#    02 12 22 32 42    52 62 72 82 92
#    01 11 21 31 41    51 61 71 81 91
#    00 10 20 30 40    50 60 70 80 90


class Layout:
	def __init__(self):

		# keys = [Key(hand, finger, letter) for ]
		# self.k00 = Key('left', 4, None)
		# self.k10 = Key('left', 4, None)
		# self.k20 = Key('left', 4, None)
		# self.k30 = Key('left', 4, None)
		# self.k40 = Key('left', 4, None)
		pass
	
	def analyze(self, corpus_file):
		
		with open(corpus_file) as file:
			# for line in file:
			# 	for char in line:
			same_hand_streak = 0
			while True:
				char = file.read(1)
				if not char:
					break

				print(char)
				char_prev = char

				if char.hand == char_prev.hand:
					# penalty
					same_hand_streak += 1
					pass


	def print_layout(self):
		k00 = self.k00.letter.char
		k10 = self.k10.letter.char
		k20 = self.k20.letter.char
		k30 = self.k30.letter.char
		k40 = self.k40.letter.char
		print(f"""
			{k00} {k10} {k20} {k30} {k40}   {k00} {k00} {k00} {k00} {k00}\n
			{k00} {k10} {k20} {k30} {k40}   {k00} {k00} {k00} {k00} {k00}
		""")

class Key:
	def __init__(self, hand, finger, letter):
		self.hand = hand
		self.finger = finger
		self.letter = letter

class Letter:
	def __init__(self, char, freq):
		self.char = char
		self.freq = freq

layout = Layout()

# a = Letter(char="a", freq=0.082)

# layout.k00.letter = a

# layout.print_layout()

corpus_file = "corpus_01.txt"
layout.analyze(corpus_file)




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