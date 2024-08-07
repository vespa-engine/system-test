# Copyright Vespa.ai. All rights reserved.

class TensorEvalQueryGenerator

def self.gen_rnd_array(num_entries)
  random_generator = Random.new(123456789)
  result = Array.new
  num_entries.times do
    result.push(random_generator.rand(100))
  end
  result
end

def self.gen_rnd_arrays(num_arrays, num_entries)
  result = Array.new
  num_arrays.times do
    result.push(gen_rnd_array(num_entries))
  end
  result
end

def self.gen_wset(query_vector)
  result = "%7B"
  num_entries = query_vector.size
  num_entries.times do |i|
    result << "," if i > 0
    result << i.to_s + ":" + query_vector[i].to_s
  end
  result << "%7D"
  result
end

def self.gen_dot_product_array(query_vector)
  "[" + query_vector.join("%20") + "]"
end

def self.gen_tensor_array(query_vector)
  query_vector.join(",")
end

def self.gen_dot_product_wset_query(query_vector)
  "/search/?rankproperty.dotProduct.wset_query=#{gen_wset(query_vector)}"
end

def self.gen_dot_product_array_query(query_vector)
  "/search/?rankproperty.dotProduct.array_query=#{gen_dot_product_array(query_vector)}"
end

def self.gen_tensor_dense_query(query_vector)
  "/search/?q_dense_vector_#{query_vector.size}=#{gen_tensor_array(query_vector)}"
end

def self.gen_tensor_dense_float_query(query_vector)
  "/search/?q_dense_float_vector_#{query_vector.size}=#{gen_tensor_array(query_vector)}"
end

def self.gen_tensor_sparse_query(query_vector, name_suffix)
  "/search/?q_sparse_#{name_suffix}=#{gen_tensor_array(query_vector)}"
end

def self.gen_tensor_sparse_query_x(query_vector)
  gen_tensor_sparse_query(query_vector, "vector_x")
end

def self.gen_tensor_sparse_float_query_x(query_vector)
  gen_tensor_sparse_query(query_vector, "float_vector_x")
end

def self.gen_tensor_sparse_query_y(query_vector)
  gen_tensor_sparse_query(query_vector, "vector_y")
end

def self.gen_tensor_sparse_query_yz(query_vector)
  gen_tensor_sparse_query(query_vector, "yz")
end

def self.write_query_file(file_name, num_queries, num_entries, query_gen_func, query_vectors)
  file = File.open(file_name, "w")
  num_queries.times do |i|
    file.write(send(query_gen_func, query_vectors[i])+"\n")
  end
  file.close
end

def self.write_query_files(folder)
  num_queries = 100
  [5,10,25,50,100,250].each do |num_entries|
    query_vectors = gen_rnd_arrays(num_queries, num_entries)
    write_query_file("#{folder}queries.dot_product_wset.#{num_entries}.txt", num_queries, num_entries, :gen_dot_product_wset_query, query_vectors)
    write_query_file("#{folder}queries.dot_product_array.#{num_entries}.txt", num_queries, num_entries, :gen_dot_product_array_query, query_vectors)
    write_query_file("#{folder}queries.tensor.dense.#{num_entries}.txt", num_queries, num_entries, :gen_tensor_dense_query, query_vectors)
    write_query_file("#{folder}queries.tensor.dense_float.#{num_entries}.txt", num_queries, num_entries, :gen_tensor_dense_float_query, query_vectors)
    write_query_file("#{folder}queries.tensor.sparse.x.#{num_entries}.txt", num_queries, num_entries, :gen_tensor_sparse_query_x, query_vectors)
    write_query_file("#{folder}queries.tensor.sparse.y.#{num_entries}.txt", num_queries, num_entries, :gen_tensor_sparse_query_y, query_vectors)
    write_query_file("#{folder}queries.tensor.sparse_float.x.#{num_entries}.txt", num_queries, num_entries, :gen_tensor_sparse_float_query_x, query_vectors)
    if num_entries <= 50
      write_query_file("#{folder}queries.tensor.sparse.yz.#{num_entries}.txt", num_queries, num_entries, :gen_tensor_sparse_query_yz, query_vectors)
    end
  end
end

end

if __FILE__ == $0
  TensorEvalQueryGenerator.write_query_files("")
end

