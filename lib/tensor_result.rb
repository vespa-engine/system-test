# Copyright Vespa.ai. All rights reserved.

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
    if value.kind_of?(Hash) && value.include?('cells') &&
       ( value.keys.size == 1 || (value.keys.size == 2 && value.include?('type')) )
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

  def approx_eq(cells_a, cells_b)
    return false unless (cells_a.length == cells_b.length)
    cells_a.zip(cells_b).each do |a,b|
      return false unless a[0] == b[0]
      return false unless (a[1]-b[1]).abs < 1e-6
    end
    return true
  end

  def ==(other)
    if @cells
      return @dimensions == other.dimensions &&
             approx_eq(@cells, other.cells)
    else
      return @value == other || @value == other.value
    end
  end

end
