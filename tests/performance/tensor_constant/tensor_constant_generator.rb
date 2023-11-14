# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class TensorConstantGenerator

  def self.gen_tensor_constant(file_name, file_size_bytes)
    puts "gen_tensor_constant: file_name='#{file_name}', file_size_bytes=#{file_size_bytes}"
    file = File.open(file_name, "w")
    file.write("{\n")
    file.write("\"cells\":  [\n")
    cell_idx = 0
    while true
      file.write(",\n") if cell_idx > 0
      file.write("{ \"address\": { \"x\": \"#{cell_idx}\" }, \"value\": #{cell_idx} }")
      cell_idx += 1
      if (cell_idx % 1000 == 0) && (file.size > file_size_bytes)
        break
      end
    end
    file.write("\n]\n")
    file.write("}\n")
    file.close
  end  

end

if __FILE__ == $0
  TensorConstantGenerator.gen_tensor_constant("tensor_constant.300MB.json", 300 * 1024 * 1024)
end
