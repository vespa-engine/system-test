# Copyright Vespa.ai. All rights reserved.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class Embedding < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
  end

  def sentencepiece_tokenizer_component
    Component.new('tokenizer').
      klass('com.yahoo.language.sentencepiece.SentencePieceEmbedder').
      bundle('linguistics-components').
      config(ConfigOverride.new('language.sentencepiece.sentence-piece').
               add(ArrayConfig.new('model').
                     add(0, ConfigValue.new('language', 'unknown')).
                     add(0, ConfigValue.new('path', 'components/en.wiki.bpe.vs10000.model'))))
  end

  def bert_embedder_component
    Component.new('transformer').
      type('bert-embedder').
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa-cloud.com/onnx_models/sentence_all_MiniLM_L6_v2.onnx' }).
      param('tokenizer-vocab', '', {'model-id' => 'ignored-on-selfhosted', 'path' => 'components/bert-base-uncased.txt'})
  end

  def huggingface_tokenizer_component
    Component.new('tokenizer').
      type('hugging-face-tokenizer').
      param('model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa-cloud.com/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.tokenizer.json'})
  end

  def huggingface_embedder_component
    Component.new('huggingface').
      type('hugging-face-embedder').
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa-cloud.com/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.onnx'}).
      param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa-cloud.com/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.tokenizer.json'}).
      param('transformer-output', 'output_0')
  end

  def huggingface_embedder_binarization_component
    Component.new('mixed').
      type('hugging-face-embedder').
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://huggingface.co/mixedbread-ai/mxbai-embed-large-v1/resolve/main/onnx/model.onnx'}).
      param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://huggingface.co/mixedbread-ai/mxbai-embed-large-v1/raw/main/tokenizer.json'}).
      param('pooling-strategy', 'cls')
  end

  def colbert_embedder_component
     Component.new('colbert').
       type('colbert-embedder').
       param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa-cloud.com/onnx_models/vespa-colMiniLM-L-6-dynamic-quantized.onnx'}).
       param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa-cloud.com/onnx_models/e5-small-v2/tokenizer.json'})
  end

  def colbert_embedder_component_fp16
    Component.new('colbert').
      type('colbert-embedder').
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://huggingface.co/mixedbread-ai/mxbai-colbert-large-v1/resolve/main/onnx/model_fp16.onnx'}).
      param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://huggingface.co/mixedbread-ai/mxbai-colbert-large-v1/raw/main/tokenizer.json'})
 end

  def splade_embedder_component
      Component.new('splade').
        type('splade-embedder').
        param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'path' => 'components/dummy.onnx'}).
        param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'path' => 'components/tokenizer.json'}).
        param('term-score-threshold', 1.15)
  end

  def default_container_setup
    Container.new('default').
      search(Searching.new).
      documentapi(ContainerDocumentApi.new).
      docproc(DocumentProcessing.new)
  end

  def test_default_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(sentencepiece_tokenizer_component)).
        sd(selfdir + 'app_one_embedder/schemas/doc.sd').
        components_dir(selfdir + 'app_one_embedder/model').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_default_embedder
  end

  def test_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(sentencepiece_tokenizer_component).
            component(bert_embedder_component)).
        sd(selfdir + 'app_two_embedders/schemas/doc.sd').
        components_dir(selfdir + 'app_two_embedders/model').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_tokens
    verify_embedding
  end

  def test_huggingface_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(huggingface_tokenizer_component).
            component(huggingface_embedder_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_huggingface_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_huggingface_tokens
    verify_huggingface_embedding
  end

  def test_huggingface_embedding_binary_quantization
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(huggingface_embedder_binarization_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_huggingface_embedder_binarization_matryoshka/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_huggingface_embedding_binary_quantization
  end

  def test_colbert_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(colbert_embedder_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_colbert_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_colbert_embedding
  end

  def test_colbert_embedding_fp16
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(colbert_embedder_component_fp16).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_colbert_embedder_fp16/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_colbert_embedding_fp16
  end

  def test_colbert_multivector_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(colbert_embedder_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_colbert_multivector_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "multivector-docs.json")
    verify_colbert_multivector_embedding
  end

  def test_splade_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(splade_embedder_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_splade_embedder/schemas/doc.sd').
        components_dir(selfdir + 'app_splade_embedder/models').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_splade_embedding
  end

  def test_splade_multivector_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(splade_embedder_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_splade_multivector_embedder/schemas/doc.sd').
        components_dir(selfdir + 'app_splade_embedder/models').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "multivector-docs.json")
    verify_splade_multivector_embedding
  end


  def verify_default_embedder
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%3B&ranking.features.query(tokens)=embed(Hello%20world)&format=json").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(tokens)"]
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(tokens)"]
    puts "queryFeature: '#{queryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    expectedEmbedding = JSON.parse('{"type":"tensor(x[5])","values":[9912.0, 0.0, 6595.0, 501.0, 0.0]}')
    assert_equal(expectedEmbedding.to_s, queryFeature.to_s)
    assert_equal(expectedEmbedding.to_s, attributeFeature.to_s)
  end

  def verify_tokens
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%3B&ranking.features.query(tokens)=embed(tokenizer, \"Hello%20world\")&format=json").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(tokens)"]
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(tokens)"]
    puts "queryFeature: '#{queryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    expectedEmbedding = JSON.parse('{"type":"tensor(x[5])","values":[9912.0, 0.0, 6595.0, 501.0, 0.0]}')
    assert_equal(expectedEmbedding.to_s, queryFeature.to_s)
    assert_equal(expectedEmbedding.to_s, attributeFeature.to_s)
  end

  def verify_embedding
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%3B&ranking.features.query(embedding)=embed(transformer, \"Hello%20world\")&format=json&format.tensors=short").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(embedding)"]
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding)"]
    puts "queryFeature: '#{queryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    #expectedEmbedding = JSON.parse('{"type":"tensor(x[32])", "values":[-0.19744643568992615, 0.17766499519348145, 0.03857016563415527, 0.14952224493026733, -0.22542041540145874, -0.9180282354354858, 0.38326385617256165, -0.03688899055123329, -0.2717420160770416, 0.08452200889587402, 0.40589264035224915, 0.3179980218410492, 0.10991743206977844, -0.15033727884292603, -0.05789601057767868, -0.15428432822227478, 0.1277512162923813, -0.12728843092918396, -0.8572669625282288, -0.10018032789230347, 0.04396097734570503, 0.31126752495765686, 0.018637821078300476, 0.18168991804122925, -0.4846144914627075, -0.16840332746505737, 0.2954804599285126, 0.2755991220474243, -0.01898312009871006, -0.3337559401988983, 0.2403516173362732, 0.12719766795635223]}')
    assert((queryFeature['values'][0] - -0.19744).abs < 1e-5)
    assert_equal(queryFeature.to_s, attributeFeature.to_s)
  end

  def verify_huggingface_tokens
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%3B&ranking.features.query(tokens)=embed(tokenizer, \"Hello%20world\")&format=json").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(tokens)"]
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(tokens)"]
    puts "queryFeature: '#{queryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    expectedEmbedding = JSON.parse('{"type":"tensor<float>(x[5])","values":[35378.0, 8999.0, 0.0, 0.0, 0.0]}')
    assert_equal(expectedEmbedding.to_s, queryFeature.to_s)
    assert_equal(expectedEmbedding.to_s, attributeFeature.to_s)
  end


  def verify_huggingface_embedding
    expected_embedding = JSON.parse(File.read(selfdir + 'hf-expected-vector.json'))
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%3B&ranking.features.query(embedding)=embed(huggingface, \"Hello%20world\")&format=json&format.tensors=short").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(embedding)"]
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding)"]
    puts "queryFeature: '#{queryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    assert_equal(queryFeature.to_s, attributeFeature.to_s)
    expected_length = 384
    assert_equal(expected_length, attributeFeature['values'].length)
    (0..expected_length-1).each { |i|
      expected = expected_embedding[i]
      actual = attributeFeature['values'][i]
      assert((expected - actual).abs < 1e-5, "#{expected} != #{actual} at index #{i}")
    }
  end

  def verify_huggingface_embedding_binary_quantization
    result = search("?yql=select%20*%20from%20sources%20*%20where%20true&input.query(embedding)=embed(mixed, \"Hello%20world\")&input.query(binary_embedding)=embed(mixed, \"Hello%20world\")&format=json&format.tensors=short").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(embedding)"]
    attributeFeatureShortFloat = result['root']['children'][0]['fields']['summaryfeatures']["attribute(shortened_embedding)"]
    
    attributeFeature = result['root']['children'][0]['fields']['summaryfeatures']["attribute(binary_embedding)"]
    queryBinaryFeature = result['root']['children'][0]['fields']['summaryfeatures']["query(binary_embedding)"]
    
    attributeFeatureShort = result['root']['children'][0]['fields']['summaryfeatures']["attribute(binary_embedding_short)"]
    attributeUnpackedFeature = result['root']['children'][0]['fields']['summaryfeatures']["unpacked"]

    puts "queryFeature: '#{queryFeature}'"
    puts "queryBinaryFeature: '#{queryBinaryFeature}'"
    puts "attributeFeature: '#{attributeFeature}'"
    puts "attributeFeatureShortFloat: '#{attributeFeatureShortFloat}'"
    puts "attributeFeatureShort: '#{attributeFeatureShort}'"
    puts "attributeUnpackedFeature: '#{attributeUnpackedFeature}'"

    relevance = result['root']['children'][0]['relevance']
    assert(relevance > 0, "#{relevance} is 0, which is not expected.")

    assert_equal(queryBinaryFeature.to_s, attributeFeature.to_s) # same input text for query and document

    # the first 512 values should be the same
    (0..511).each { |i|
      assert((queryFeature['values'][i] - attributeFeatureShortFloat['values'][i]).abs < 1e-5, "#{queryFeature['values'][i]} != #{attributeFeatureShortFloat['values'][i]} at index #{i}")
    }
    
    expected_length = 128
    assert_equal(expected_length, attributeFeature['values'].length)
    assert_equal(expected_length, queryBinaryFeature['values'].length)
    assert_equal(8*expected_length, queryFeature['values'].length)
    assert_equal(8*expected_length, attributeUnpackedFeature['values'].length)
    
    assert_equal(2, attributeFeatureShort['values'].length)

    expected_embedding = JSON.parse(File.read(selfdir + 'hf-binarized-expected-vector.json'))
    (0..expected_length-1).each { |i|
      expected = expected_embedding[i]
      actual = attributeFeature['values'][i]
      assert_equal(expected, actual)
    }
    # Matryoshka chop 16 first float dims and binaryze to int8
    # should be the same as the first two dims as when binarizing with more dimensions
    result = search("?yql=select%20*%20from%20sources%20*%20where%20true&input.query(binary_embedding_short)=embed(mixed, \"Hello%20world\")&format=json&format.tensors=short").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(binary_embedding_short)"]
    puts "queryFeature: '#{queryFeature}'"
    assert_equal(2, queryFeature['values'].length)

    assert_equal(expected_embedding[0], queryFeature['values'][0])
    assert_equal(expected_embedding[1], queryFeature['values'][1])

    assert_equal(expected_embedding[0], attributeFeatureShort['values'][0])
    assert_equal(expected_embedding[1], attributeFeatureShort['values'][1])

  end

  def verify_colbert_embedding
    result = search("?query=text:hello&input.query(qt)=embed(colbert, \"Hello%20world\")&format=json&format.tensors=short-value").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(qt)"]
    assert_equal(32, queryFeature.length)
    puts result
    embedding_compressed = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_compressed)"]
    embedding_bfloat = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_bfloat)"]
    embedding_float = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_float)"]

    assert_equal(5, embedding_compressed.length) # 5 tokens
    assert_equal(4, embedding_compressed['0'].length) #1 token embedding dim is 4

    assert_equal(5, embedding_bfloat.length) # 5 tokens
    assert_equal(32, embedding_bfloat['0'].length) # token embedding is 32

    assert_equal(5, embedding_float.length) # 5 tokens
    assert_equal(32, embedding_float['0'].length) # token embedding is 32

    maxSimFloat = result['root']['children'][0]['fields']['summaryfeatures']["maxSimFloat"]
    assert(maxSimFloat > 29.5, "#{maxSimFloat} < 29.5 maxSimFloat not greater than 29.5")

    maxSimBFloat = result['root']['children'][0]['fields']['summaryfeatures']["maxSimBFloat"]
    assert(maxSimBFloat > 29.5, "#{maxSimBFloat} < 29.5 maxSimBfloat not greater than 29.5")

    assert((maxSimBFloat - maxSimFloat).abs < 1e-1, "#{maxSimBFloat} != #{maxSimFloat} maxSimBfloat not equal to maxSimFloat")
  end

  def verify_colbert_embedding_fp16
    result = search("?query=text:hello&input.query(qt)=embed(colbert, \"Hello%20world\")&format=json&format.tensors=short-value").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(qt)"]
    assert_equal(32, queryFeature.length)
    puts result
    embedding_compressed = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_compressed)"]
    embedding_bfloat = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_bfloat)"]
    embedding_float = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_float)"]

    assert_equal(5, embedding_compressed.length) # 5 tokens
    assert_equal(16, embedding_compressed['0'].length) #1 token embedding dim is 16

    assert_equal(5, embedding_bfloat.length) # 5 tokens
    assert_equal(128, embedding_bfloat['0'].length) #1 token embedding is 128

    assert_equal(5, embedding_float.length) # 5 tokens
    assert_equal(128, embedding_float['0'].length) #1 token embedding is 128

    maxSimFloat = result['root']['children'][0]['fields']['summaryfeatures']["maxSimFloat"]
    assert(maxSimFloat > 29.5, "#{maxSimFloat} < 29.5 maxSimFloat not greater than 29.5")

    maxSimBFloat = result['root']['children'][0]['fields']['summaryfeatures']["maxSimBFloat"]
    assert(maxSimBFloat > 29.5, "#{maxSimBFloat} < 29.5 maxSimBfloat not greater than 29.5")

    assert((maxSimBFloat - maxSimFloat).abs < 1e-1, "#{maxSimBFloat} != #{maxSimFloat} maxSimBfloat not equal to maxSimFloat")
  end

  def verify_colbert_multivector_embedding
    result = search("?query=text:hello&input.query(qt)=embed(colbert, \"Hello%20world\")&format=json&format.tensors=short-value").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(qt)"]
    assert_equal(32, queryFeature.length)
    puts result
    embedding = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding)"]

    assert_equal(10, embedding.length) # 10 tokens
    assert_equal(32, embedding[0]['values'].length) # token embedding is 32

    embedding_compressed = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding_compressed)"]
    assert_equal(10, embedding_compressed.length) # 10 tokens
    assert_equal(4, embedding_compressed[0]['values'].length) # token embedding is 32/8 = 4 values

    maxSim = result['root']['children'][0]['fields']['summaryfeatures']["maxSim"]
    assert(maxSim['0'] > 29.5, "#{maxSim['0']} < 29.5 maxSim['0'] not greater than 29.5")
    assert(maxSim['1'] > 21.5, "#{maxSim['0']} < 21.5 maxSim['1'] not greater than 21.5")
  end

  def verify_splade_embedding
    result = search("?query=text:hello&input.query(qt)=embed(splade, \"Hello%20world\")&format=json&format.tensors=short-value").json
    querySpladeEmbedding     = result['root']['children'][0]['fields']['summaryfeatures']["query(qt)"]
    assert(querySpladeEmbedding.length > 0, "#{querySpladeEmbedding} length is 0")
    puts "querySpladeEmbedding: '#{querySpladeEmbedding}'"
    docSpladeEmbedding = result['root']['children'][0]['fields']['summaryfeatures']["attribute(dt)"]
    puts(docSpladeEmbedding.length)
    puts "docSpladeEmbedding: '#{docSpladeEmbedding}'"
    assert(docSpladeEmbedding.length > 0, "#{docSpladeEmbedding} lenght is 0.")
    relevance = result['root']['children'][0]['relevance']
    assert(relevance > 0, "#{relevance} is 0, which is not expected.")
  end

  def verify_splade_multivector_embedding
    result = search("?query=text:hello&input.query(qt)=embed(splade, \"Hello%20world\")&format=json&format.tensors=short-value").json
    querySpladeEmbedding     = result['root']['children'][0]['fields']['summaryfeatures']["query(qt)"]
    assert(querySpladeEmbedding.length > 0, "#{querySpladeEmbedding} length is 0")
    puts "querySpladeEmbedding: '#{querySpladeEmbedding}'"
    docSpladeEmbedding = result['root']['children'][0]['fields']['summaryfeatures']["attribute(dt)"]
    puts(docSpladeEmbedding.length)
    puts "docSpladeEmbedding: '#{docSpladeEmbedding}'"
    assert(docSpladeEmbedding.length > 0, "#{docSpladeEmbedding} lenght is 0.")
    relevance = result['root']['children'][0]['relevance']
    assert(relevance > 0, "#{relevance} is 0, which is not expected.")
  end

  def teardown
    stop
  end

end
