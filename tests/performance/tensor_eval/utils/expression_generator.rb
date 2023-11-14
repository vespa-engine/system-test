# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
def gen_tensor(dim_x, dim_y, dim_size)
  @random_generator = Random.new(123456789)
  result = "{"
  for i in 0...dim_size do
    for j in 0...dim_size do
      result << ",\n" if (i > 0 || j > 0)
      result << "{#{dim_x}:#{i},#{dim_y}:#{j}}:#{@random_generator.rand(100)}"
    end
  end
  result << "}"
end

def gen_match_expression(file_name, dim_size)
  file = File.open(file_name, "w")
  file.write("sum(match(tensorFromWeightedSet(query(wset_query),x)*tensorFromWeightedSet(attribute(wset),y),\n")
  file.write(gen_tensor("x", "y", dim_size))
  file.write("))")
  file.close
end

def gen_matrix_expression(file_name, dim_size)
  file = File.open(file_name, "w")
  file.write("sum(sum((query(qvector#{dim_size})+attribute(dvector#{dim_size}))*\n")
  file.write(gen_tensor("x", "y", dim_size))
  file.write(",x))")
  file.close
end

if __FILE__ == $0
  gen_match_expression("tensor_match_25x25.expression", 25)
  gen_match_expression("tensor_match_50x50.expression", 50)
  gen_match_expression("tensor_match_100x100.expression", 100)
  gen_matrix_expression("tensor_matrix_product_10x10.expression", 10)
  gen_matrix_expression("tensor_matrix_product_25x25.expression", 25)
  gen_matrix_expression("tensor_matrix_product_50x50.expression", 50)
  gen_matrix_expression("tensor_matrix_product_100x100.expression", 100)
end

