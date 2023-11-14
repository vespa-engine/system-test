# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class VespaResultHit
  def initialize
    @fields = {}
  end

  def add_field(name, value)
    @fields[name] = value
  end

  def add_field_filtered(name, values, idx)
    filtered = []
    idx.each do |i|
      filtered.push(values[i])
    end
    @fields[name] = filtered
  end

  def to_xml
    res = "  <hit>\n"
    @fields.each do |key, value|
      if value.class == Array
        if value.size == 0
          res += "    <field name=\"" + key + "\"></field>\n"
        else
          res += "    <field name=\"" + key + "\">\n"
          value.each do |item|
            if item.class == Array # weighted set (item[0] = value, item[1] = weight)
              res += "      <item weight=\"" + item[1].to_s + "\"\>" + item[0].to_s + "</item>\n"
            else # array
              res += "      <item>" + item.to_s + "</item>\n"
            end
          end
          res += "    </field>\n"
        end
      else # single
        itemend = "</item>\n"
        endlen = itemend.length
        fieldvalue = value.to_s
        tail = fieldvalue[-endlen, endlen]
        if tail == itemend
          # embedded XML needs trailing indent
          fieldvalue += "    "
        end
        res += "    <field name=\"" + key + "\">" + fieldvalue + "</field>\n"
      end
    end
    res += "  </hit>\n"
  end
end

class VespaResult
  def initialize
    @hits = []
    @num_hits = 0
  end

  def add_hit(hit)
    @hits.push(hit)
    @num_hits += 1
  end

  def to_xml
    res = "<result total-hit-count=\"" + @num_hits.to_s + "\">\n"
    @hits.each do |hit|
      res += hit.to_xml
    end
    res += "</result>\n"
  end

  def clear
    @hits = []
    @num_hits = 0
  end
end


