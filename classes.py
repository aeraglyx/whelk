import random
import time

# https://www.researchgate.net/publication/268254341_Force_measurement_of_hand_and_fingers
# https://www.researchgate.net/publication/2423272_A_System_For_Measuring_Finger_Forces_During_Grasping
# https://pubmed.ncbi.nlm.nih.gov/15273677/

# 1 58.55 29 25
# 2 54.40 31 35
# 3 37.45 23 25
# 4 29.60 17 14

# 1.4 1.0 1.4 1.666

class Layout:

	def __init__(self):

		def symmetrize(list):
			new_list = [
				list[0], list[1], list[2], list[3], list[3], list[2], list[1], list[0],
				list[4], list[5], list[6], list[7], list[7], list[6], list[5], list[4],
				list[8], list[9], list[10], list[11], list[11], list[10], list[9], list[8]]
			return new_list
		
		self.row_map = [1] * 8 + [0] * 8 + [-1] * 8
		self.finger_map = [
			4, 3, 2, 1, 1, 2, 3, 4,
			4, 3, 2, 1, 1, 2, 3, 4,
			4, 3, 2, 1, 1, 2, 3, 4]
		effort_map = [
			5.0, 2.0, 1.4, 1.7,
			3.0, 1.5, 1.0, 1.2,
			4.0, 3.0, 1.8, 1.5]
		self.effort_map = symmetrize(effort_map)
		finger_strength = [0.28, 0.34, 0.23, 0.15]
		finger_efforts = [2.3, 1.5, 1.0, 1.2]
		# self.hand_map = [
		# 	0, "left", "left", "left", "right", "right", "right", "right",
		# 	0, "left", "left", "left", "right", "right", "right", "right",
		# 	0, "left", "left", "left", "right", "right", "right", "right"]
		self.hand_map = ([0] * 4 + [1] * 4) * 3
		self.char_map = [
			"b", "w", "f", "p", "l", "u", "y", "j",
			"a", "r", "s", "t", "n", "e", "i", "o",
			"z", "v", "c", "d", "h", "g", "m", "k"]
		self.time = [None] * 24
		# TODO swaping keys themselves?
		# TODO make sure not to delete the best layouts
		self.score = None

		self.update()
	

	def update(self):
		self.char_dict = {}
		for i, char in enumerate(self.char_map):
			if char is not None:
				self.char_dict[char.lower()] = Key(self.hand_map[i], self.finger_map[i], self.row_map[i], self.effort_map[i])

	def swap_rnd(self):
		rnd = random.sample(range(0, 23), 2)
		self.char_map[rnd[0]], self.char_map[rnd[1]] = self.char_map[rnd[1]], self.char_map[rnd[0]]

	def swap_home_row(self):
		rnd = random.sample(range(8, 15), 2)
		self.char_map[rnd[0]], self.char_map[rnd[1]] = self.char_map[rnd[1]], self.char_map[rnd[0]]

	def swap_not_home_row(self):
		rnd = random.sample(list(range(0, 7)) + list(range(16, 23)), 2)
		self.char_map[rnd[0]], self.char_map[rnd[1]] = self.char_map[rnd[1]], self.char_map[rnd[0]]

	def swap_yes(self):
		# for _ in range(random.randint(1, 2)):
		# 	self.swap_not_home_row()
		# if random.random() < 0.5:
		# 	self.swap_home_row()
		for _ in range(random.randint(1, 3)):
			self.swap_rnd()
	
	def analyze(self, data):

		SFB_PENALTY = 4.0
		INWARD_ROLL = 0.7
		OUTWARD_ROLL = 1.2

		#  0 - thumb
		#  1 - index
		#  2 - middle
		#  3 - ring
		#  4 - little
		
		# with open(corpus_file) as file:
		# 	data = file.read()

		score = 0.0
		key_prev = None
		same_hand_streak = 0
		same_finger_streak = 0
		roll_streak = 0

		char_count = 0
		sfb_count = 0
		roll_count = 0
		left_hand_count = 0

		for char in data:

			char = char.lower()
			# if not char:
			# 	break
			
			char_count += 1
			
			key = self.char_dict[char] if char in self.char_dict else None
			
			if not key:
				key_prev = None
				same_hand_streak += 0.5
				left_hand_count += 0.5
				continue

			if not key_prev:
				key_prev = key
				continue

			if key.hand == 0:
				left_hand_count += 1

			# key_effort = key.effort
			# finger_efforts = [2.3, 1.5, 1.0, 1.2]
			
			match key.finger:
				case 1:
					key_effort = 1.2
				case 2:
					key_effort = 1.0
				case 3:
					key_effort = 1.5
				case 4:
					key_effort = 2.3
			
			if key.row != 0:
				key_effort *= 1.5


			if key.hand == key_prev.hand:
				# same hand
				key_effort *= 1 + same_hand_streak * 0.25
				same_hand_streak += 1
				
				if key.finger == key_prev.finger:
					# SFB
					sfb_count += 1
					key_effort *= SFB_PENALTY
				
				if key.finger < key_prev.finger:
					# inward roll
					roll_streak += 1
					roll_count += 1
					key_effort *= INWARD_ROLL
				if key.finger > key_prev.finger:
					# outward roll
					roll_streak += 1
					roll_count += 1
					key_effort *= OUTWARD_ROLL

				travel = abs(key.row - key_prev.row)
				travel = 1 + travel * 0.5
				key_effort *= travel

			else:
				# alternating
				same_hand_streak = 1

			key_prev = key
			score += key_effort

		self.score = score / char_count
		self.sfb = sfb_count / char_count
		self.roll = roll_count / char_count
		self.hand = left_hand_count / char_count
		# print(self.score)
		# TODO stats object


	def mirror(self):
		pass

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
	
	def print_stats(self):
		print(f"Score:   {self.score:.4f}")
		print(f"SFB:     {self.sfb:.4f}")
		print(f"Rolls:   {self.roll:.4f}")
		print(f"Balance: {self.hand:.4f} / {1 - self.hand:.4f}")
		# TODO finger usage

				

class Key:
	def __init__(self, hand, finger, row, effort):
		self.hand = hand
		self.finger = finger
		self.row = row
		self.effort = effort

class Letter:
	def __init__(self, char, freq):
		self.char = char
		self.freq = freq