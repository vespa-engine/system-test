# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

  def teardown
    stop
  end

end
