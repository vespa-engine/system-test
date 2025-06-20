# Copyright Vespa.ai. All rights reserved.

import argparse as ap
import bisect
import sys
import urllib.parse


def read_dictionary():
    result = []
    for line in sys.stdin:
        parts = line.split('\t')
        word = parts[0]
        matches = int(parts[1])
        word_freq = float(parts[2])
        total_freq = float(parts[3])
        result.append((word, matches, word_freq, total_freq))
    return result


def get_yql(word, max_edit_distance, prefix_length, f_value):
    yql = 'select * from sources * where content contains({maxEditDistance:%i,prefixLength:%i}fuzzy("%s"))' % (max_edit_distance, prefix_length, word)
    if f_value:
        yql += ' and filter = %i' % f_value
    return yql


def get_query(word, max_edit_distance, prefix_length, f_value):
    params = { 'yql': get_yql(word, max_edit_distance, prefix_length, f_value),
               'presentation.summary': 'minimal' }
    return '/search/?' + urllib.parse.urlencode(params)


parser = ap.ArgumentParser()
parser.add_argument('-l', '--lowerfreq', type=float, default=0.001)
parser.add_argument('-u', '--upperfreq', type=float, default=0.01)
parser.add_argument('-m', '--maxeditdistance', type=int, default=2)
parser.add_argument('-p', '--prefixlength', type=int, default=0)
parser.add_argument('-f', '--filter', type=int, default=None)
args = parser.parse_args()

raw_dict = read_dictionary()
# Sort on total frequency (lowest first)
sorted_dict = sorted(raw_dict, key=lambda x: x[3])
freqs = [total_freq for word, matches, word_freq, total_freq in sorted_dict]
# TODO: With Python 3.10 bisect_left supports key=lambda x: x[3]
lower = bisect.bisect_left(freqs, args.lowerfreq)
upper = bisect.bisect_left(freqs, args.upperfreq)
for i in range(lower, upper):
    print(get_query(sorted_dict[i][0], args.maxeditdistance, args.prefixlength, args.filter))

