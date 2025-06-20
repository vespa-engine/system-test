# Copyright Vespa.ai. All rights reserved.

import argparse as ap
import bisect
import enchant

# Prerequisites
# pip3 install pyenchant

def is_fuzzy_match(lhs, rhs, max_edits):
    lhs_len = len(lhs)
    rhs_len = len(rhs)
    if lhs_len + max_edits < rhs_len:
        return False
    if rhs_len + max_edits < lhs_len:
        return False
    return enchant.utils.levenshtein(lhs, rhs) <= max_edits


def find_fuzzy_matches(word, word_dict):
    matches = 0
    freq = 0.0
    for entry in word_dict:
        if is_fuzzy_match(word, entry[0], 2):
            matches += 1
            freq += entry[1]
    return (matches, freq)


def read_dictionary(file_name, dict_docs):
    result = []
    with open(file_name, 'r') as file:
        for line in file:
            parts = line.strip().split('\t')
            word = parts[0]
            raw_freq = int(parts[1])
            scaled_freq = min(1.0, raw_freq / dict_docs)
            result.append((word, scaled_freq))
    return result


parser = ap.ArgumentParser()
parser.add_argument('dictfile', type=str)
parser.add_argument('-d', '--dictdocs', type=int, default=20)
parser.add_argument('-f', '--freqcat', type=float, default=0.001)
parser.add_argument('-w', '--wordspercat', type=int, default=10)
args = parser.parse_args()

word_dict = read_dictionary(args.dictfile, args.dictdocs)
# Sort on frequency (lowest first)
sorted_dict = sorted(word_dict, key=lambda x: x[1])
freqs = [freq for word, freq in sorted_dict]
# TODO: With Python 3.10 bisect_left supports key=lambda x: x[3]
idx = bisect.bisect_left(freqs, args.freqcat)
for i in range(idx, min(len(sorted_dict), idx + args.wordspercat)):
    entry = sorted_dict[i]
    matches = find_fuzzy_matches(entry[0], word_dict)
    print('%s\t%i\t%f\t%f' % (entry[0], matches[0], entry[1], matches[1]))

