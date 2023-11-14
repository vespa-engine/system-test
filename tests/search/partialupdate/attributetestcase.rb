# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'documentupdate'
require 'search/partialupdate/vesparesult'

class AttributeTestCase

  attr_reader :testcase
  attr_reader :max_doc

  @@fielddata = Struct.new("FieldData", :name, :type, :values)

  def initialize(doc_type, max_doc)
    @doc_type = doc_type
    @id_prefix = "id:attr/attr:#{doc_type}::"
    @max_doc = max_doc
    @updates = []
    @result = VespaResult.new
    @hit_id = 0
    @fields = []
  end

  def doc_type
    @doc_type
  end

  def fields_to_compare
    retval = []
    @fields.each do |fd|
      retval.push(fd.name)
    end
    retval.push("sortfield")
    return retval
  end

  def write(file, objects)
    file.write("<vespafeed>\n")
    objects.each do |obj|
      file.write(obj.to_xml + "\n")
    end
    file.write("</vespafeed>\n")
  end

  def generate_max_doc(file)
    doc = Document.new(@doc_type, @id_prefix + @max_doc.to_s)
    write(file, [doc])
  end

  def create_update(id)
    upd = DocumentUpdate.new(@doc_type, @id_prefix + id.to_s)
    @updates.push(upd)
    return upd
  end

  def create_hit
    hit = VespaResultHit.new
    @result.add_hit(hit)
    return hit
  end

end

class SingleAttributeTestCase < AttributeTestCase

  def initialize(doc_type = "attrsingle")
    super(doc_type, 10)

    ints = [100000, -200000, 30, 40, 20, 300, 3, 400, 36, 12]
    longs = [10000000000, -20000000000, 3000, 3010, 2990, 30000, 300, 30100, 3600, 1200]
    bytes = [5, 20, 10, 20, 0, 100, 1, 200, 12, 4]
    floats = [1000.5, -2000.5, 30.5, 40.5, 20.5, 305.0, 3.05, 405.0, 36.6, 12.2]
    doubles = [10000.5, -20000.5, 300.5, 310.5, 290.5, 3005.0, 30.05, 3105.0, "360.59999999999997", 120.2] # TODO: use less decimal values

    @fields.push(@@fielddata.new("int", "intval", ints))
    @fields.push(@@fielddata.new("long", "longval", longs))
    @fields.push(@@fielddata.new("byte", "byteval", bytes))
    @fields.push(@@fielddata.new("float", "floatval", floats))
    @fields.push(@@fielddata.new("double", "doubleval", doubles))

    @fields.push(@@fielddata.new("fsint", "intval", ints))
    @fields.push(@@fielddata.new("fslong", "longval", longs))
    @fields.push(@@fielddata.new("fsbyte", "byteval", bytes))
    @fields.push(@@fielddata.new("fsfloat", "floatval", floats))
    @fields.push(@@fielddata.new("fsdouble", "doubleval", doubles))

    @fields.push(@@fielddata.new("string", "stringval", ["first", "second", "third"]))
    @fields.push(@@fielddata.new("fsstring", "stringval", ["first", "second", "third"]))
  end

  def query
    "/?query=hitfield:hit&nocache&hits=20"
  end

  def check_docs_query
    "/?query=int:30&nocache"
  end

  def sort_field
    "sortfield"
  end

  def perform_arithmetic(field)
    if field == "string" or field == "fsstring"
      return false
    else
      return true
    end
  end

  def generate_documents(file)
    documents = []
    testcase.output("generate #{@max_doc} documents") if testcase
    for i in 0...@max_doc
      doc = Document.new(@doc_type, @id_prefix + i.to_s).
        add_field("sortfield", i.to_s).
        add_field("hitfield", "hit")
      @fields.each do |fd|
        doc.add_field(fd.name, fd.values[2])
      end
      documents.push(doc)
    end
    testcase.output("generated #{@max_doc} documents") if testcase
    write(file, documents)
  end

  def generate_max_doc(file)
    # this is to ensure that you do not get nan for float and double attributes
    doc = Document.new(@doc_type, @id_prefix + @max_doc.to_s)
    @fields.each do |fd|
      doc.add_field(fd.name, 0)
    end
    write(file, [doc])
  end

  def add_operation(update, operation, id)
    @fields.each do |fd|
      update.addOperation(operation, fd.name, fd.values[id])
    end
  end

  def add_simple_alter_operation(update, operation, number)
    @fields.each do |fd|
      if perform_arithmetic(fd.name)
        update.addSimpleAlterOperation(operation, fd.name, number)
      end
    end
  end

  def generate_updates(file)
    # regular operations
    upd = create_update(0)
    add_operation(upd, "assign", 0)
    upd = create_update(1)
    add_operation(upd, "assign", 1)

    # alter operations
    upd = create_update(2)
    add_simple_alter_operation(upd, "increment", 10)
    upd = create_update(3)
    add_simple_alter_operation(upd, "decrement", 10)
    upd = create_update(4)
    add_simple_alter_operation(upd, "multiply", 10)
    upd = create_update(5)
    add_simple_alter_operation(upd, "divide", 10)
    upd = create_update(6)
    add_simple_alter_operation(upd, "multiply", 1.2)
    upd = create_update(7)
    add_simple_alter_operation(upd, "divide", 2.5)

    # This test is not supposed to work in Vespa 3.0
    #upd = create_update(8)
    #add_simple_alter_operation(upd, "increment", 20)
    #add_simple_alter_operation(upd, "decrement", 10)
    #add_simple_alter_operation(upd, "multiply", 100)
    #add_simple_alter_operation(upd, "divide", 10)

    write(file, @updates)
    @updates.clear
  end

  def add_hit(idx, use_string = true)
    hit = create_hit
    @fields.each do |fd|
      if (not perform_arithmetic(fd.name)) and (not use_string)
        hit.add_field(fd.name, fd.values[2])
      else
        hit.add_field(fd.name, fd.values[idx])
      end
    end
    hit.add_field("sortfield", @hit_id)
    @hit_id = @hit_id + 1
  end

  def generate_result(file)
    # regular operations
    add_hit(0)
    add_hit(1)

    # alter operations
    add_hit(3, false)
    add_hit(4, false)
    add_hit(5, false)
    add_hit(6, false)
    add_hit(8, false)
    add_hit(9, false)
    #add_hit(7, false) # this is not supposed to work in Vespa 3.0
    add_hit(2)

    # no changed on this
    add_hit(2)

    file.write(@result.to_xml)
    @result.clear
    @hit_id = 0
  end
end

if __FILE__ == $0
  single = SingleAttributeTestCase.new
  File.open("singledocs.tmp", "w") do |file|
    single.generate_documents(file)
  end
  File.open("singleupdates.tmp", "w") do |file|
    single.generate_updates(file)
  end
  File.open("singlemaxdoc.tmp", "w") do |file|
    single.generate_max_doc(file)
  end
  File.open("singleresult.tmp", "w") do |file|
    single.generate_result(file)
  end
end


class SingleAttributeSummaryTestCase < SingleAttributeTestCase
  def initialize
    super("attrsinglesummary")
    @fields.push(@@fielddata.new("istring", "stringval", ["aa bb cc", "dd ee ff", "gg hh ii"]))
  end

  def query
    "/?query=hitfield:hit&nocache&hits=20"
  end

  def perform_arithmetic(field)
    if field == "istring"
      return false
    end
    return super(field)
  end
end


class SingleAttributeTestCaseExtra < SingleAttributeTestCase

  def initialize
    super
  end

  def generate_updates(file)
    # This test is not supposed to work in Vespa 3.0
    upd = create_update(0)
    add_simple_alter_operation(upd, "increment", 20)
    add_simple_alter_operation(upd, "decrement", 10)
    add_simple_alter_operation(upd, "multiply", 100)
    add_simple_alter_operation(upd, "divide", 10)

    write(file, @updates)
    @updates.clear
  end

  def generate_result(file)
    add_hit(7)

    for i in 0...@max_doc-1
      add_hit(2)
    end

    file.write(@result.to_xml)
    @result.clear
    @hit_id = 0
  end
end



class ArrayAttributeTestCase < AttributeTestCase

  def initialize(doc_type = "attrarray")
    super(doc_type, 11)

    ints = [100000, -200000, 25, 30]
    longs = [10000000000, -20000000000, 25, 3000]
    bytes = [10, 20, 25, 30]
    floats = [1000.5, -2000.5, 25.5, 30.5]
    doubles = [10000.5, -20000.5, 250.5, 300.5]
    strings = ["first", "second", "secondhalf", "third"]

    @fields.push(@@fielddata.new("int", "intval", ints))
    @fields.push(@@fielddata.new("long", "longval", longs))
    @fields.push(@@fielddata.new("byte", "byteval", bytes))
    @fields.push(@@fielddata.new("float", "floatval", floats))
    @fields.push(@@fielddata.new("double", "doubleval", doubles) )

    @fields.push(@@fielddata.new("fsint", "intval", ints))
    @fields.push(@@fielddata.new("fslong", "longval", longs))
    @fields.push(@@fielddata.new("fsbyte", "byteval", bytes))
    @fields.push(@@fielddata.new("fsfloat", "floatval", floats))
    @fields.push(@@fielddata.new("fsdouble", "doubleval", doubles) )

    @fields.push(@@fielddata.new("string", "stringval", strings))
    @fields.push(@@fielddata.new("fsstring", "stringval", strings))
  end

  def query
    "/?query=hitfield:hit&nocache&hits=20"
  end

  def check_docs_query
    "/?query=int:30&nocache"
  end

  def sort_field
    "sortfield"
  end

  def generate_documents(file)
    documents = []
    for i in 0...@max_doc
      doc = Document.new(@doc_type, @id_prefix + i.to_s)
      doc.add_field("sortfield", i.to_s)
      doc.add_field("hitfield", "hit")
      @fields.each do |fd|
        doc.add_field(fd.name, [fd.values[3]])
      end
      documents.push(doc)
    end
    write(file, documents)
  end

  def add_operation(update, operation, idx)
    @fields.each do |fd|
      arg = []
      idx.each do |i|
        arg.push(fd.values[i])
      end
      update.addOperation(operation, fd.name, arg)
    end
  end

  def generate_updates(file)
    # regular operations
    upd = create_update(0)
    add_operation(upd, "assign", [0])
    upd = create_update(1)
    add_operation(upd, "assign", [0, 1])
    upd = create_update(2)
    add_operation(upd, "assign", [0, 0, 1, 1])
    upd = create_update(3)
    add_operation(upd, "add", [0])
    upd = create_update(4)
    add_operation(upd, "add", [0, 0])
    upd = create_update(5)
    add_operation(upd, "add", [0, 1])
    upd = create_update(6)
    add_operation(upd, "add", [0, 0, 1, 1, 2])
    upd = create_update(7)
    add_operation(upd, "assign", [])
    # TODO: activate when fixed in IL
    #upd = create_update(8)
    #add_operation(upd, "assign", [0, 1])
    #add_operation(upd, "add", [2])
    # TODO: activate when fixed in IL
    #upd = create_update(9)
    #add_operation(upd, "add", [2])
    #add_operation(upd, "assign", [0, 1])

    write(file, @updates)
    @updates.clear
  end

  def add_hit(idx)
    hit = create_hit
    if idx.length > 0
      @fields.each do |fd|
        hit.add_field_filtered(fd.name, fd.values, idx)
      end
    end
    hit.add_field("sortfield", @hit_id)
    @hit_id = @hit_id + 1
  end

  def generate_result(file)
    # regular operations
    add_hit([0])
    add_hit([0, 1])
    add_hit([0, 0, 1, 1])
    add_hit([0, 3])
    add_hit([0, 0, 3])
    add_hit([0, 1, 3])
    add_hit([0, 0, 1, 1, 2, 3])
    add_hit([])
    #add_hit([0, 1, 2])
    add_hit([3])
    #add_hit([0, 1])
    add_hit([3])

    # no changes on this
    add_hit([3])

    file.write(@result.to_xml)
    @result.clear
    @hit_id = 0
  end
end

if __FILE__ == $0
  array = ArrayAttributeTestCase.new
  File.open("arraydocs.tmp", "w") do |file|
    array.generate_documents(file)
  end
  File.open("arrayupdates.tmp", "w") do |file|
    array.generate_updates(file)
  end
  File.open("arraymaxdoc.tmp", "w") do |file|
    array.generate_max_doc(file)
  end
  File.open("arrayresult.tmp", "w") do |file|
    array.generate_result(file)
  end
end


class ArrayAttributeSummaryTestCase < ArrayAttributeTestCase
  def initialize
    super("attrarraysummary")
    @fields.push(@@fielddata.new("istring", "stringval", ["aa bb", "cc dd", "ee ff", "gg hh"]))
  end

  def query
    "/?query=hitfield:hit&nocache&hits=20"
  end
end


class ArrayAttributeTestCaseExtra < ArrayAttributeTestCase

  def initialize
    super
  end

  def generate_updates(file)
    # TODO: activate when fixed in IL
    upd = create_update(0)
    add_operation(upd, "assign", [0, 1])
    add_operation(upd, "add", [2])
    # TODO: activate when fixed in IL
    upd = create_update(1)
    add_operation(upd, "add", [2])
    add_operation(upd, "assign", [0, 1])

    write(file, @updates)
    @updates.clear
  end

  def generate_result(file)
    add_hit([0, 1, 2])
    add_hit([0, 1])

    for i in 0...@max_doc-2
      add_hit([3])
    end

    file.write(@result.to_xml)
    @result.clear
    @hit_id = 0
  end
end



class WeightedSetAttributeTestCase < AttributeTestCase

  def initialize(doc_type = "attrweightedset")
    super(doc_type, 28)

    int = [[100000, 10], [-200000, -20], [25, 25], [30, 30]]
    long = [[10000000000, 10], [-20000000000, -20], [2500, 25], [3000, 30]]
    byte = [[10, 10], [20, -20], [25, 25], [30, 30]]
    string = [["first", 10], ["second", -20], ["secondhalf", 25], ["third", 30]]

    @fields.push(@@fielddata.new("int", "intval", int))
    @fields.push(@@fielddata.new("long", "longval", long))
    @fields.push(@@fielddata.new("byte", "byteval", byte))

    @fields.push(@@fielddata.new("fsint", "intval", int))
    @fields.push(@@fielddata.new("fslong", "longval", long))
    @fields.push(@@fielddata.new("fsbyte", "byteval", byte))

    @fields.push(@@fielddata.new("string", "stringval", string))
    @fields.push(@@fielddata.new("fsstring", "stringval", string))

    @fields.push(@@fielddata.new("intcr", "intval", int))
    @fields.push(@@fielddata.new("longcr", "longval", long))
    @fields.push(@@fielddata.new("bytecr", "byteval", byte))
    @fields.push(@@fielddata.new("stringcr", "stringval", string))
    @fields.push(@@fielddata.new("tagcr", "stringval", string))
    @fields.push(@@fielddata.new("fsstringcr", "stringval", string))
    @fields.push(@@fielddata.new("fstagcr", "stringval", string))

  end

  def query
    "/?query=hitfield:hit&nocache&hits=40"
  end

  def check_docs_query
    "/?query=int:30&nocache"
  end

  def sort_field
    "sortfield"
  end

  def regular_weightedset(name)
    if name[-2, 2] == "cr"
      return false
    else
      return true
    end
  end

  def generate_documents(file)
    documents = []
    for i in 0...@max_doc
      doc = Document.new(@doc_type, @id_prefix + i.to_s)
      doc.add_field("sortfield", i.to_s)
      doc.add_field("hitfield", "hit")
      @fields.each do |fd|
        doc.add_field(fd.name, [fd.values[3]])
      end
      documents.push(doc)
    end
    write(file, documents)
  end

  def add_operation(update, operation, idx)
    @fields.each do |fd|
      arg = []
      idx.each do |i|
        if operation == "remove"
          arg.push(fd.values[i][0])
        else
        arg.push(fd.values[i])
        end
      end
      update.addOperation(operation, fd.name, arg)
    end
  end

  def add_simple_alter_operation(update, operation, number, idx)
    @fields.each do |fd|
      update.addSimpleAlterOperation(operation, fd.name, number, fd.values[idx][0])
    end
  end

  def generate_updates(file)
    # assign
    upd = create_update(0)
    add_operation(upd, "assign", [0])
    upd = create_update(1)
    add_operation(upd, "assign", [0, 1])

    # add
    upd = create_update(2)
    add_operation(upd, "add", [0])
    upd = create_update(3)
    add_operation(upd, "add", [0, 0])
    upd = create_update(4)
    add_operation(upd, "add", [0, 1])
    upd = create_update(5)
    add_operation(upd, "add", [0, 0, 1, 1, 2])

    # remove
    upd = create_update(6)
    add_operation(upd, "remove", [3]) # remove existing key
    upd = create_update(7)
    add_operation(upd, "remove", [3, 3]) # remove existing key twice
    upd = create_update(8)
    add_operation(upd, "remove", [0]) # remove nonexisting key
    upd = create_update(9)
    add_operation(upd, "remove", [0, 0]) # remove nonexisting key twice
    upd = create_update(10)
    add_operation(upd, "assign", []) # clear

    # combined
    upd = create_update(11)
    add_operation(upd, "assign", [0, 1])
    upd = create_update(11)
    add_operation(upd, "add", [2])
    upd = create_update(12)
    add_operation(upd, "add", [2])
    upd = create_update(12)
    add_operation(upd, "assign", [0, 1])
    upd = create_update(13)
    add_operation(upd, "add", [0, 1, 2])
    upd = create_update(13)
    add_operation(upd, "remove", [1, 3]) # remove some
    upd = create_update(14)
    add_operation(upd, "assign", [0, 1, 2, 3])
    upd = create_update(14)
    add_operation(upd, "remove", [1, 3]) # remove some
    upd = create_update(15)
    add_operation(upd, "remove", [1, 3]) # remove first
    upd = create_update(15)
    add_operation(upd, "add", [0, 1, 2])
    upd = create_update(16)
    add_operation(upd, "remove", [1, 3]) # remove first
    upd = create_update(16)
    add_operation(upd, "assign", [0, 1, 2, 3])
    upd = create_update(17)
    add_operation(upd, "add", [0, 1])
    upd = create_update(17)
    add_operation(upd, "remove", [0, 1, 3]) # remove all
    upd = create_update(18)
    add_operation(upd, "assign", [0, 1, 3])
    upd = create_update(18)
    add_operation(upd, "remove", [0, 1, 3]) # remove all

    # alter operations
    upd = create_update(19)
    add_simple_alter_operation(upd, "increment", 10, 3)
    upd = create_update(20)
    add_simple_alter_operation(upd, "decrement", 10, 3)
    upd = create_update(21)
    add_simple_alter_operation(upd, "multiply", 10, 3)
    upd = create_update(22)
    add_simple_alter_operation(upd, "divide", 10, 3)

    upd = create_update(23) # several on same key
    add_simple_alter_operation(upd, "increment", 20, 3)
    add_simple_alter_operation(upd, "decrement", 10, 3)
    add_simple_alter_operation(upd, "multiply", 100, 3)
    add_simple_alter_operation(upd, "divide", 10, 3)

    upd = create_update(24) # several on different keys
    add_operation(upd, "assign", [0, 1, 2, 3])
    upd = create_update(24) # several on different keys
    add_simple_alter_operation(upd, "increment", 10, 0)
    add_simple_alter_operation(upd, "increment", 10, 1)
    add_simple_alter_operation(upd, "increment", 10, 2)
    add_simple_alter_operation(upd, "increment", 10, 3)

    # remove if zero
    upd = create_update(25)
    @fields.each do |fd|
      upd.addSimpleAlterOperation("decrement", fd.name, 30, fd.values[3][0])
    end

    # create if non existant
    upd = create_update(26)
    @fields.each do |fd|
      upd.addSimpleAlterOperation("increment", fd.name, 25, fd.values[2][0])
    end

    write(file, @updates)
    @updates.clear
  end

  def add_hit(idx)
    hit = create_hit
    if idx.length > 0
      @fields.each do |fd|
        hit.add_field_filtered(fd.name, fd.values, idx)
      end
    end
    hit.add_field("sortfield", @hit_id)
    @hit_id = @hit_id + 1
  end

  def add_hit_weight(idx_weight_pairs)
    hit = create_hit
    @fields.each do |fd|
      values = []
      idx_weight_pairs.each do |pair|
        values.push([fd.values[pair[0]][0], pair[1]])
      end
      hit.add_field(fd.name, values)
    end
    hit.add_field("sortfield", @hit_id)
    @hit_id = @hit_id + 1
  end

  def generate_result(file)
    # assign
    add_hit([0])
    add_hit([0, 1])

    # add
    add_hit([0, 3])
    add_hit([0, 3])
    add_hit([0, 1, 3])
    add_hit([0, 1, 2, 3])

    # remove
    add_hit([])
    add_hit([])
    add_hit([3])
    add_hit([3])
    add_hit([])

    # combined
    add_hit([0, 1, 2])
    add_hit([0, 1])
    add_hit([0, 2])
    add_hit([0, 2])
    add_hit([0, 1, 2])
    add_hit([0, 1, 2, 3])
    add_hit([])
    add_hit([])

    # alter operations
    add_hit_weight([[3, 40]])
    add_hit_weight([[3, 20]])
    add_hit_weight([[3, 300]])
    add_hit_weight([[3, 3]])

    add_hit_weight([[3, 400]])
    add_hit_weight([[0, 20], [1, -10], [2, 35], [3, 40]])

    # remove if zero
    hit = create_hit
    @fields.each do |fd|
      if regular_weightedset(fd.name)
        hit.add_field(fd.name, [[fd.values[3][0], 0]])
      end
    end
    hit.add_field("sortfield", @hit_id)
    @hit_id = @hit_id + 1

    # create if non-existent
    hit = create_hit
    @fields.each do |fd|
      if regular_weightedset(fd.name)
        hit.add_field_filtered(fd.name, fd.values, [3])
      else
        hit.add_field_filtered(fd.name, fd.values, [2, 3])
      end
    end
    hit.add_field("sortfield", @hit_id)
    @hit_id = @hit_id + 1

    # no changes on this
    add_hit([3])

    file.write(@result.to_xml)
    @result.clear
    @hit_id = 0
  end
end

if __FILE__ == $0
  weightedset = WeightedSetAttributeTestCase.new
  File.open("weightedsetdocs.tmp", "w") do |file|
    weightedset.generate_documents(file)
  end
  File.open("weightedsetupdates.tmp", "w") do |file|
    weightedset.generate_updates(file)
  end
  File.open("weightedsetmaxdoc.tmp", "w") do |file|
    weightedset.generate_max_doc(file)
  end
  File.open("weightedsetresult.tmp", "w") do |file|
    weightedset.generate_result(file)
  end
end


class WeightedSetAttributeSummaryTestCase < WeightedSetAttributeTestCase
  def initialize
    super("attrweightedsetsummary")
    string = [["aa bb", 10], ["cc dd", -20], ["ee ff", 25], ["gg hh", 30]]
    @fields.push(@@fielddata.new("istring", "stringval", string))
    @fields.push(@@fielddata.new("istringcr", "stringval", string))
    @fields.push(@@fielddata.new("itagcr", "stringval", string))
  end

  def query
    "/?query=hitfield:hit&nocache&hits=40"
  end
end

