# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import sys
import re
import json


def read_json_file(file_path):
    data = None
    with open(file_path, "r") as f:
        data = json.load(f)

    return data[0:10]


def write_json_file(terms, file_path):
    feed_list = [
        "/search/?query=text:"+term+"\n"
        for term in terms
    ]
    with open(file_path, "w") as f:
        f.writelines(feed_list)


def read_common_words(file_path):
    common_words = set()
    with open(file_path, "r") as f:
        lines = f.readlines()
        for line in lines:
            common_words.add(line.strip())
    return common_words


def clean_text(text):
    return re.split(r"[^a-z0-9]+", text.lower())


def count_terms(doc, term_length=1, common_words=set()):
    terms_set = set()
    win_len = term_length
    for i in range(len(doc) + 1 - win_len):
        if not any(
            map(lambda word: word in common_words, doc[i : i + win_len])
        ):
            term = "+text:".join(doc[i : i + win_len])
            terms_set.add(term)
    return terms_set


def process_doc(doc_fields, term_length=1, common_words=set()):
    if doc_fields["text"]:
        terms_set = count_terms(
            clean_text(doc_fields["text"]), term_length, common_words
        )
        return terms_set
    else:
        return set()


def process_docs(obj, term_length=1, common_words=set()):
    doc_counts = [
        process_doc(doc["fields"], term_length, common_words) for doc in obj
    ]
    terms_set = set()
    # all unique terms
    for counts in doc_counts:
        for term in counts:
            terms_set.add(term)

    return terms_set


def main():
    if len(sys.argv) == 3:
        write_json_file(process_docs(read_json_file(sys.argv[1])), sys.argv[2])
    elif len(sys.argv) == 4:
        write_json_file(
            process_docs(read_json_file(sys.argv[1]), int(sys.argv[3])),
            sys.argv[2],
        )
    elif len(sys.argv) == 5:
        write_json_file(
            process_docs(
                read_json_file(sys.argv[1]),
                int(sys.argv[3]),
                read_common_words(sys.argv[4]),
            ),
            sys.argv[2],
        )
    else:
        print(
            "Wrong number of arguments:",
            "python3",
            "count_terms.py",
            "infile.json",
            "outfile.json",
            "[number_of_words_in_term [common_words.txt]]",
        )


if __name__ == "__main__":
    main()
