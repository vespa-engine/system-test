# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/ann_sift_base'

class AnnSiftQuantizedPerfTest < AnnSiftBase

  def test_sift_data_set_quantized_1_bit
    do_test_sift_data_set_quantized_1_bit(bits: 1)
  end

  def test_sift_data_set_quantized_2_bits
    do_test_sift_data_set_quantized_1_bit(bits: 2)
  end

  def test_sift_data_set_quantized_3_bits
    do_test_sift_data_set_quantized_1_bit(bits: 3)
  end

  def test_sift_data_set_quantized_4_bits
    do_test_sift_data_set_quantized_1_bit(bits: 4)
  end

  def do_test_sift_data_set_quantized_1_bit(bits:)
    set_owner('vekterli')
    set_description("Test performance and recall (exact+HNSW) over the 1M SIFT (128 dim) "+
                    "dataset using #{bits}-bit quantization")
    run_quantized_sift_test(selfdir + 'sift_test_quantized', bits: bits)
  end

end
