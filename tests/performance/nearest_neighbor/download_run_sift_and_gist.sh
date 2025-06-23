#!/bin/sh

set -e
set -x

mkdir -p sift-data gist-data
(
	cd sift-data || exit 1
	g++ -O ../make_docs.cpp -o make_docs
	g++ -O ../make_queries.cpp -o make_queries

	wget ftp://ftp.irisa.fr/local/texmex/corpus/sift.tar.gz
	tar -xvf sift.tar.gz
	sh -x ../create_sift_test_data.sh
)

(
	cd gist-data || exit 1
	g++ -O ../make_docs.cpp -o make_docs
	g++ -O ../make_queries.cpp -o make_queries

	wget ftp://ftp.irisa.fr/local/texmex/corpus/gist.tar.gz
	tar -xvf gist.tar.gz
	sh -x ../create_gist_test_data.sh
)
