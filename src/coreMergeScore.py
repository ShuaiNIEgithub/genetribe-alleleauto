#!/usr/bin/env python3
import sys
import numpy as np
#
def getbed(bed):
	dc = {}
	with open(bed) as BED:
		for i in BED:
			i = i.strip().split('\t')
			dc[i[3]] = [i[0],int(i[1])]
		#
	return dc
#
def file2colinearitydc(colinearity_file):
	colinearity_block = {}
	with open(colinearity_file) as FILE:
		for i in FILE:
			i = i.strip().split('\t')
			key = i[0]+','+i[3]
			info = [int(i[1]),int(i[2]),int(i[4]),int(i[5]),float(i[6])]
			colinearity_block.setdefault(key,[]).append(info)
		#
	#
	return colinearity_block

#
def merge(colinearity_block,dc1,dc2,score):
	with open(score) as FILE:
		for i in FILE:
			i = i.strip().split('\t')
			key = i[0]+','+i[1]
			#
			try:
				pos1 = dc1[i[0]]
			except KeyError:
				continue
			chr1 = pos1[0]
			start1 = pos1[1]
			#
			try:
				pos2 = dc2[i[1]]
			except KeyError:
				continue
			chr2 = pos2[0]
			start2 = pos2[1]
			#
			score_list = []
			if chr1+','+chr2 in colinearity_block:
				info = colinearity_block[chr1+','+chr2]
				for j in range(len(info)):
					tmp_pos = info[j]
					if tmp_pos[0] <= start1 <= tmp_pos[1] and tmp_pos[2] <= start2 <= tmp_pos[3]:
						score_list.append(float(tmp_pos[4]))
					#
				#
			#
			if len(score_list) ==0:
				block_score = 0
			else:
				block_score = np.median(score_list)
			print ('\t'.join(i)+'\t'+str(block_score))
		#
	#
#

from optparse import OptionParser
def main():
	usage = "Usage: %prog -i score -c colinearityScore -a bed1 -b bed2 > output\n" \
	"Description: merge score, and calculate the gene score in the colinearity block"
	parser = OptionParser(usage)
	parser.add_option("-i", dest="score",help="Input file", metavar="FILE")
	parser.add_option("-c", dest="colinearityScore",help="block_pos file", metavar="FILE")
	parser.add_option("-a", dest = "bed1_file",help="first bed",metavar="FILE")
	parser.add_option("-b", dest="bed2_file",help="second bed", metavar="FILE")
	(options, args) = parser.parse_args()
	dc1 = getbed(options.bed1_file)
	dc2 = getbed(options.bed2_file)
	colinearity_dc = file2colinearitydc(options.colinearityScore)
	merge(colinearity_dc,dc1,dc2,options.score)
#
if __name__ == "__main__":
	main()
