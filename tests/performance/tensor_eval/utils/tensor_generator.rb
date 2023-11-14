# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class TensorEvalTensorGenerator

  def self.gen_2d_tensor(dim_x, dim_y, dim_size)
    random_generator = Random.new(123456789)
    result = "{\n"
    result << "  \"cells\": [\n"
    for i in 0...dim_size do
      for j in 0...dim_size do
        result << ",\n" if (i > 0 || j > 0)
        result << "    { \"address\": { \"#{dim_x}\": \"#{i}\", \"#{dim_y}\": \"#{j}\" }, \"value\": #{random_generator.rand(100)}.0 }"
      end
    end
    result << "\n  ]"
    result << "\n}"
  end

  def self.write_2d_tensor_file(file_name, dim_size)
    file = File.open(file_name, "w")
    file.write(gen_2d_tensor("x", "y", dim_size))
    file.close
  end

  def self.write_tensor_files(folder)
    write_2d_tensor_file("#{folder}/sparse_tensor_25x25.json", 25)
    write_2d_tensor_file("#{folder}/sparse_tensor_50x50.json", 50)
    write_2d_tensor_file("#{folder}/sparse_tensor_100x100.json", 100)
    write_2d_tensor_file("#{folder}/dense_matrix_10x10.json", 10)
    write_2d_tensor_file("#{folder}/dense_matrix_25x25.json", 25)
    write_2d_tensor_file("#{folder}/dense_matrix_50x50.json", 50)
    write_2d_tensor_file("#{folder}/dense_matrix_100x100.json", 100)
  end

end

if __FILE__ == $0
  TensorEvalTensorGenerator.write_tensor_files(".")
end

