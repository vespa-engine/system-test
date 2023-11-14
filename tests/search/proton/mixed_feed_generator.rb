# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
module MixedFeedGenerator

  PUTDOC=1
  UPDATEDOC=2
  REMOVEDOC=3

  def generate_mixed_feed(f, startid, numelems, updatemod, removemod)
    agemap = Hash.new
    prevdocid = nil
    state = PUTDOC
    numputs = 0
    numupdates = 0
    numremoves = 0
    for i in startid..(startid + numelems - 1) do
      docid = "id:banana:banana::doc#{i}"
      color = "yellow#{i}"
      age = i
      item1 = "old#{i}"
      item2 = "new#{i}"
      if prevdocid != nil then
          if state == PUTDOC then
              if (i % updatemod) == 0 then
                  state = UPDATEDOC
              elsif (i % removemod) == 0 then
                  state = REMOVEDOC
              else
                  state = PUTDOC
              end
          else
              state = PUTDOC
          end
      end
      document = ""
      if state == PUTDOC then
          document += "<document documenttype=\"banana\" documentid=\"#{docid}\">\n"
          document += "  <colour>#{color}</colour>\n"
          document += "  <age>#{age}</age>\n"
          document += "  <similarfruits>\n"
          document += "    <item>#{item1}</item>\n"
          document += "    <item>#{item2}</item>\n"
          document += "  </similarfruits>\n"
          document += "</document>\n"
          numputs += 1
      elsif state == UPDATEDOC then
          document += "<update documenttype=\"banana\" documentid=\"#{prevdocid}\">\n"
          document += "<increment field=\"age\" by=\"#{numelems}\" />\n"
          document += "</update>\n"
          numupdates += 1
      elsif state == REMOVEDOC then
          document += "<remove documentid=\"#{prevdocid}\" />\n";
          numremoves += 1
      end
      f.puts(document)
      prevdocid = docid
    end
    return numputs, numupdates, numremoves
  end

end
