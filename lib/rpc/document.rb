# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class DocumentType
  def serialize
    [@name, @version].pack('aL')
  end

  def attr_id(key)

  end
end

class DocumentId

  def serialize
    buf = ""
    buf += [13 + @id.length].pack('L')
    if (@gid != nil)
      buf += [1,
      @gid & 0xffffffff,
      (@gid >> 32) & 0xffffffff,
      (@gid >> 64) & 0xffffffff, 0].pack('cLLLQ')
    else
      buf += [0].pack('c')
    end
    buf += [0, @id].pack('Qa')
    buf
  end
end

class StringValue < String
  def serialize
    if length < 0x400 then

    end
  end
end

class Document
  def serialize
    buf = [0, @version].pack('ls')
    buf += @doctype.serialize
    buf += @docid.serialize

    field_buf = ""
    field_ptrs = Array.new

    @fields.each do |key, value|
      cur_field = value.serialize
      field_ptrs.push([@doctype.attr_id(key), cur_field.length])
      field_buf += cur_field
    end

    buf += [field_buf.length, field_buf.length, 0, @fields.size].pack('LLLL')

    @field_ptrs.each do |field_ptr|
      if field_ptr[0] < 0x80 then
        buf += [field_ptr[0]].pack('C')
      elsif field_ptr[0] < 0x80000000 then
        buf += [field_ptr[0] + 0x80000000].pack('N')
      else
        raise RuntimeError, "Field id too high", caller
      end
      if field_ptr[1] < 0x80 then
        buf += [field_ptr[1]].pack('C')
      elsif field_ptr[1] < 0x4000 then
        buf += [field_ptr[1] + 0x8000].pack('n')
      elsif field_ptr[1] < 0x40000000 then
        buf += [field_ptr[1] + 0xC0000000].pack('N')
        field_id_c = 'N'
      else
        raise RuntimeError, "Field too long", caller
      end
    end
    buf += field_buf
    buf
  end

end
