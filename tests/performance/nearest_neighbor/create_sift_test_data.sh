#!/bin/bash

# Dense tensor
./make_docs sift put 0 10000 true false vec_m16 > docs.10k.json
./make_docs sift put 0 1000000 true false vec_m16 > docs.1M.json
./make_docs sift update 0 10000 false false vec_m16 > updates.10k.json
./make_docs sift update 500000 200000 false false vec_m16 > updates.200k.json

# Mixed tensor
./make_docs sift put 0 1000000 true true vec_m16 > docs.mixed.1M.json
./make_docs sift update 500000 200000 false true vec_m16 > updates.mixed.200k.json

for i in 10 100
do
    ./make_queries sift 10000 vec_m16 false $i 0 > queries.vec_m16.ap-false.th-$i.eh-0.txt
done

# Various explore_hits for target_hits=10
for i in 0 10 30 70 110 190 390 590 790
do
    ./make_queries sift 10000 vec_m16 true 10 $i > queries.vec_m16.ap-true.th-10.eh-$i.txt
done

# Various explore_hits for target_hits=100
for i in 0 20 100 300 500 700
do
    ./make_queries sift 10000 vec_m16 true 100 $i > queries.vec_m16.ap-true.th-100.eh-$i.txt
done

# Various query filter percentages
for i in 1 10 50 90 95 99
do
    ./make_queries sift 10000 vec_m16 true 100 0 $i > queries.vec_m16.ap-true.th-100.eh-0.f-$i.txt
    ./make_queries sift 10000 vec_m16 false 100 0 $i > queries.vec_m16.ap-false.th-100.eh-0.f-$i.txt
done

./make_queries sift 10 > query_vectors.10.txt
./make_queries sift 100 > query_vectors.100.txt
