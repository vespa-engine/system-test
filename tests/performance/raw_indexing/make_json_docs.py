# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

import sys
import json
import os
import re


def add_start_bracket(filepath_out):
     with open(filepath_out, "w") as file:
        file.write("[\n")

def read_jsonl_file(number, filepath, filepath_out):
    add_start_bracket(filepath_out)
    id_counter = 0
    with open(filepath, "r") as file:
        for i in range(number):
            line = next(file)
            text = extract_text(line)
            text_mod = re.sub(r'[^\x20-\x7F]+',' ', text)
            json_document = format_json(text_mod, id_counter)
            write_json_to_file(json_document, i == number-1, filepath_out)
            id_counter += 1

def extract_text(text):
    try:
         data = json.loads(text)
    except json.decoder.JSONDecodeError as e:
         print("Decoding json failed: ", e)
    return data["text"]

def format_json(text, id_counter):
    document = {"text": text}
    json_document = {"fields": document ,"put": "id:doc:doc::"+str(id_counter)}
    return json_document

def write_json_to_file(json_document, check, filepath_out):
    with open(filepath_out, "a") as outfile:
        json.dump(json_document, outfile, indent=2)
        if check:
            outfile.write("\n]")
        else:
            outfile.write(",\n")  



def main():
    read_jsonl_file(int(sys.argv[1]), sys.argv[2], sys.argv[3])


if __name__ == '__main__':
    main()
