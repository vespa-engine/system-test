# Copyright Vespa.ai. All rights reserved.

import argparse as ap
import random
import urllib.parse

def random_vector(dimension):
    return [random.randint(0, 100000)/100000.0 for _ in range(dimension)]


def get_query(target_hits, dimension, user_id):
    params = { 'yql': 'select * from sources * where {targetHits:%s}nearestNeighbor(embedding,qemb)' % target_hits,
               'input.query(qemb)': random_vector(dimension),
               'streaming.groupname': '%i' % user_id,
               'presentation.summary': 'minimal',
               'hits': target_hits }
    return '/search/?' + urllib.parse.urlencode(params)


def gen_queries(args):
    user_id_range = 10000000 # Must match the same definition in create_docs.cpp
    start_id = user_id_range * args.batch
    user_ids = list(range(start_id, start_id + args.users))
    random.shuffle(user_ids)
    for user_id in user_ids[:args.queries]:
        print(get_query(args.targethits, args.dimension, user_id))



parser = ap.ArgumentParser()
parser.add_argument('-d', '--dimension', type=int, default=1)
parser.add_argument('-t', '--targethits', type=int, default=10)
parser.add_argument('-u', '--users', type=int, default=100)
parser.add_argument('-q', '--queries', type=int, default=10)
parser.add_argument('-b', '--batch', type=int, default=1)
parser.add_argument('-s', '--seed', type=int, default=1234)
args = parser.parse_args()
random.seed(args.seed)
gen_queries(args)

