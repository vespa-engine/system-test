# Copyright Vespa.ai. All rights reserved.
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
    f.puts("[\n")
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
          document += "{ \"put\": \"#{docid}\",\n"
          document += " \"fields\": {"
          document += " \"colour\": \"#{color}\","
          document += " \"age\": #{age},"
          document += " \"similarfruits\": [ \"#{item1}\", \"#{item2}\" ]"
          document += "  }\n"
          document += "}"
          numputs += 1
      elsif state == UPDATEDOC then
          document += "{ \"update\": \"#{prevdocid}\","
          document += "  \"fields\": { \"age\": { \"increment\": #{numelems} } }"
          document += "}"
          numupdates += 1
      elsif state == REMOVEDOC then
          document += "{ \"remove\": \"#{prevdocid}\" }";
          numremoves += 1
      end
      f.puts(document)
      if i < startid + numelems - 1
        f.puts ","
      end
      prevdocid = docid
    end
    f.puts("]\n")
    return numputs, numupdates, numremoves
  end

end
