# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class TensorResult
  attr_reader :cells
  attr_reader :dimensions
  attr_reader :value

  def extract_cell_dimensions(input_cells)
    dimhash = {}
    input_cells.each do |c|
      c['address'].each { |d,v| dimhash[d] = true }
    end
    dimhash.keys.sort
  end

  def extract_cell_values(input_cells, dimensions)
    cells = []
    input_cells.each do |c|
      addr = c['address']
      dimvals = []
      dimensions.each { |d| dimvals.append(addr[d]) }
      v = [ dimvals, c['value'] ]
      cells.append(v)
    end
    return cells.sort
  end

  def initialize(value)
    @value = value
    @cells = nil
    @dimensions = nil
    input_cells = value
    if value.kind_of?(Hash) && value.include?('cells') && value.keys.size == 1
      input_cells = value['cells']
    end
    if input_cells.kind_of?(Array)
      @dimensions = extract_cell_dimensions(input_cells)
      @cells = extract_cell_values(input_cells, @dimensions)
    end
  end

  def to_s
    if @cells && @cells.any?
      stringval = "tensor#{@dimensions} {\n"
      @cells.each do |cell|
        coords = cell[0]
        value = cell[1]
        stringval += "  cell #{coords} : #{value}\n"
      end
      stringval += "}"
      return stringval
    else
      return @value.to_s
    end
  end

  def inspect
    to_s
  end

  def ==(other)
    if @cells
      return @dimensions == other.dimensions &&
             @cells == other.cells
    else
      return @value == other || @value == other.value
    end
  end

end
