# Copyright Vespa.ai. All rights reserved.
#
# Generates documents and queries for the sparse tensor WAND performance test.
#
# Usage:
#   ruby gen_data.rb docs <num_docs>
#   ruby gen_data.rb queries <variant> <target_hits> <num_queries>
#
# Labels are drawn from a skewed (log-uniform) distribution over the vocabulary,
# so that some labels are common and most are rare. All variants of the queries are
# generated from the same random seed, and thus contain the same labels and weights.
# The weights are integers, so the tensor fields and the weighted set field hold the same values.

require 'json'
require 'uri'

VOCABULARY_SIZE = 100_000
DOC_LABELS = 48
QUERY_LABELS = 16

def random_label(rnd)
  "t#{(VOCABULARY_SIZE ** rnd.rand).to_i - 1}"
end

def random_cells(rnd, num_labels)
  cells = {}
  while cells.size < num_labels
    cells[random_label(rnd)] = rnd.rand(1..100)
  end
  cells
end

def write_docs(num_docs)
  rnd = Random.new(4711)
  puts "["
  (1..num_docs).each do |id|
    cells = random_cells(rnd, DOC_LABELS)
    doc = { "put" => "id:test:test::#{id}",
            "fields" => { "id" => id,
                          "sv" => { "cells" => cells },
                          "sv_fast" => { "cells" => cells },
                          "ws" => cells } }
    puts(JSON.generate(doc) + (id < num_docs ? "," : ""))
  end
  puts "]"
end

def encode(value)
  URI.encode_www_form_component(value)
end

def query_url(variant, target_hits, cells)
  tensor = "{" + cells.map { |label, weight| "#{label}:#{weight}" }.join(",") + "}"
  tokens = "{" + cells.map { |label, weight| "'#{label}':#{weight}" }.join(",") + "}"
  case variant
  when "stw"
    yql = "select * from sources * where {targetHits:#{target_hits}}sparseTensorWand(sv, q)"
    "/search/?yql=#{encode(yql)}&ranking.features.query(q)=#{encode(tensor)}&ranking.profile=stw"
  when "stw_fast"
    yql = "select * from sources * where {targetHits:#{target_hits}}sparseTensorWand(sv_fast, q)"
    "/search/?yql=#{encode(yql)}&ranking.features.query(q)=#{encode(tensor)}&ranking.profile=stw_fast"
  when "wand"
    yql = "select * from sources * where {targetHits:#{target_hits}}wand(ws, @tokens)"
    "/search/?yql=#{encode(yql)}&tokens=#{encode(tokens)}&ranking.profile=wand"
  when "bruteforce"
    yql = "select * from sources * where true"
    "/search/?yql=#{encode(yql)}&ranking.features.query(q)=#{encode(tensor)}&ranking.profile=bruteforce"
  else
    raise "Unknown query variant '#{variant}'"
  end
end

def write_queries(variant, target_hits, num_queries)
  rnd = Random.new(1234)
  num_queries.times do
    puts query_url(variant, target_hits, random_cells(rnd, QUERY_LABELS))
  end
end

case ARGV[0]
when "docs"
  write_docs(Integer(ARGV[1]))
when "queries"
  write_queries(ARGV[1], Integer(ARGV[2]), Integer(ARGV[3]))
else
  raise "Usage: gen_data.rb docs <num_docs> | gen_data.rb queries <variant> <target_hits> <num_queries>"
end
