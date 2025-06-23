# Copyright Vespa.ai. All rights reserved.
#!/bin/bash

for p in 0 1
do
    cat dict.us.analyze.* | python3 create_queries.py -l 0.0001 -u 0.001 -p $p > queries_m0.01_p$p\_fnone.txt
    cat dict.us.analyze.* | python3 create_queries.py -l 0.001 -u 0.01 -p $p > queries_m0.1_p$p\_fnone.txt
    cat dict.us.analyze.* | python3 create_queries.py -l 0.01 -u 0.1 -p $p > queries_m1_p$p\_fnone.txt
    cat dict.us.analyze.* | python3 create_queries.py -l 0.1 -u 0.5 -p $p > queries_m10_p$p\_fnone.txt
    cat dict.us.analyze.* | python3 create_queries.py -l 0.5 -u 2.0 -p $p > queries_m50_p$p\_fnone.txt
done

cat dict.us.analyze.* | python3 create_queries.py -l 0.01 -u 0.1 -f 1 > queries_m1_p0_f0.1.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.01 -u 0.1 -f 10 > queries_m1_p0_f1.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.01 -u 0.1 -f 100 > queries_m1_p0_f10.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.01 -u 0.1 -f 500 > queries_m1_p0_f50.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.01 -u 0.1 -f 900 > queries_m1_p0_f90.txt

cat dict.us.analyze.* | python3 create_queries.py -l 0.1 -u 0.5 -f 1 > queries_m10_p0_f0.1.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.1 -u 0.5 -f 10 > queries_m10_p0_f1.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.1 -u 0.5 -f 100 > queries_m10_p0_f10.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.1 -u 0.5 -f 500 > queries_m10_p0_f50.txt
cat dict.us.analyze.* | python3 create_queries.py -l 0.1 -u 0.5 -f 900 > queries_m10_p0_f90.txt

