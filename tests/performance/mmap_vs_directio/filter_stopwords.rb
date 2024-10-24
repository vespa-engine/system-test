# Copyright Vespa.ai. All rights reserved.

# Takes in raw natural language queries (one per line) and outputs new queries
# with stop words filtered away. Stop words are all terms with a document frequency
# greater than or equal to `max_df` configured below.
# Uses a preprocessed word frequency list file of the form:
# <total document count>\n
# <term 1>\t<term 1 document frequency>\n
# ...
# <term N>\t<term N document frequency>\n

max_df = 0.20
stop_words = []
File.open('word_freqs.txt', 'r') do |f|
  doc_count = f.readline.to_i
  f.each_line do |line|
    parts = line.split("\t")
    term = parts[0].strip
    freq = parts[1].strip.to_f
    term_df = freq / doc_count
    break if term_df < max_df
    stop_words << term
  end
end

#puts "Stop words: #{stop_words}"

# Create one unified regex for case-insensitively matching all stop words
# at word boundaries.
filter_regex = /\b(#{stop_words.join('|')})\b/i
# Removing stop words leaves around redundant whitespace, so have a secondary
# cleanup regex to collapse these down to a single space.
normalize_spaces_regex = /(\s{2,})/

ARGF.each_line do |line|
  filtered = line.gsub(filter_regex, '').gsub(normalize_spaces_regex, ' ').strip
  #puts "#{line.strip}\n#{filtered}\n\n"
  puts filtered
end
