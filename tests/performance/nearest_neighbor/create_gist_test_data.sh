#!/bin/bash

./make_docs gist put 0 1000 true false vec_m16 > docs.1k.json
./make_docs gist put 0 300000 true false vec_m16 > docs.300k.json

for i in 10 100
do
    ./make_queries gist 1000 vec_m16 false $i 0 > queries.vec_m16.ap-false.th-$i.eh-0.txt
done

# Various explore_hits for target_hits=10
for i in 0 10 30 70 110 190 390 590 790
do
    ./make_queries gist 1000 vec_m16 true 10 $i > queries.vec_m16.ap-true.th-10.eh-$i.txt
done

# Various explore_hits for target_hits=100
for i in 0 20 100 300 500 700
do
    ./make_queries gist 1000 vec_m16 true 100 $i > queries.vec_m16.ap-true.th-100.eh-$i.txt
done

# Various query filter percentages
for i in 1 10 50 90 95 99
do
    ./make_queries gist 1000 vec_m16 true 100 0 $i > queries.vec_m16.ap-true.th-100.eh-0.f-$i.txt
    ./make_queries gist 1000 vec_m16 false 100 0 $i > queries.vec_m16.ap-false.th-100.eh-0.f-$i.txt
done

./make_queries gist 10 > query_vectors.10.txt
./make_queries gist 100 > query_vectors.100.txt

