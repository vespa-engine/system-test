# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa.oath.cloud/onnx_models/sentence_all_MiniLM_L6_v2.onnx' }).
      param('tokenizer-vocab', '', {'model-id' => 'ignored-on-selfhosted', 'path' => 'components/bert-base-uncased.txt'})
  end

  def huggingface_tokenizer_component
    Component.new('tokenizer').
      type('hugging-face-tokenizer').
      param('model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa.oath.cloud/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.tokenizer.json'})
  end

  def huggingface_embedder_component
    Component.new('huggingface').
      type('hugging-face-embedder').
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa.oath.cloud/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.onnx'}).
      param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa.oath.cloud/onnx_models/paraphrase-multilingual-MiniLM-L12-v2.tokenizer.json'}).
      param('transformer-output', 'output_0')
  end

  def colbert_embedder_component
     Component.new('colbert').
       type('colbert-embedder').
       param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa.oath.cloud/onnx_models/vespa-colMiniLM-L-6-dynamic-quantized.onnx'}).
       param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://data.vespa.oath.cloud/onnx_models/e5-small-v2/tokenizer.json'})
    end

    def splade_embedder_component
      Component.new('splade').
        type('splade-embedder').
        param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'path' => 'components/dummy.onnx'}).
        param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'path' => 'components/tokenizer.json'}).
        param('term-score-threshold', 1.15)
     end
  

  def test_default_embedding
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            component(sentencepiece_tokenizer_component).
            search(Searching.new).
            docproc(DocumentProcessing.new)).
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
          Container.new('default').
            component(sentencepiece_tokenizer_component).
            component(bert_embedder_component).
            search(Searching.new).
            docproc(DocumentProcessing.new)).
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
          Container.new('default').
            component(huggingface_tokenizer_component).
            component(huggingface_embedder_component).
            search(Searching.new).
            docproc(DocumentProcessing.new).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_huggingface_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_huggingface_tokens
    verify_huggingface_embedding
  end

  def test_colbert_embedding
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            component(colbert_embedder_component).
            search(Searching.new).
            docproc(DocumentProcessing.new).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_colbert_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_colbert_embedding
  end

  def test_colbert_multivector_embedding
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            component(colbert_embedder_component).
            search(Searching.new).
            docproc(DocumentProcessing.new).
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
          Container.new('default').
            component(splade_embedder_component).
            search(Searching.new).
            docproc(DocumentProcessing.new).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_splade_embedder/schemas/doc.sd').
        components_dir(selfdir + 'app_splade_embedder/models').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_splade_embedding
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

  def verify_colbert_multivector_embedding
    result = search("?query=text:hello&input.query(qt)=embed(colbert, \"Hello%20world\")&format=json&format.tensors=short-value").json
    queryFeature     = result['root']['children'][0]['fields']['summaryfeatures']["query(qt)"]
    assert_equal(32, queryFeature.length)
    puts result
    embedding = result['root']['children'][0]['fields']['summaryfeatures']["attribute(embedding)"]

    assert_equal(10, embedding.length) # 10 tokens
    prinf("embedding: #{embedding}")
    assert_equal(32, embedding['0']['0'].length) # token embedding is 32

    maxSimFloat = result['root']['children'][0]['fields']['summaryfeatures']["maxSim"]
    assert(maxSimFloat > 29.5, "#{maxSim} < 29.5 maxSim not greater than 29.5")

    assert((maxSimBFloat - maxSimFloat).abs < 1e-1, "#{maxSimBFloat} != #{maxSimFloat} maxSimBfloat not equal to maxSimFloat")
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

  def teardown
    stop
  end

end
