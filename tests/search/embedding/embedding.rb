# Copyright Vespa.ai. All rights reserved.

require 'rubygems'
require 'json'
require 'cgi'
require 'indexed_streaming_search_test'

class Embedding < IndexedStreamingSearchTest

  def setup
    set_owner("bjorncs")
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

  def huggingface_embedder_onnx_external_data_component
    Component.new('huggingface').
      type('hugging-face-embedder').
      param('transformer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://huggingface.co/intfloat/multilingual-e5-large/resolve/main/onnx/model.onnx'}).
      param('tokenizer-model', '', {'model-id' => 'ignored-on-selfhosted', 'url' => 'https://huggingface.co/intfloat/multilingual-e5-large/resolve/main/onnx/tokenizer.json'})
  end

  def nomic_modernbert_component
    Component.new('nomicmb').
      type('hugging-face-embedder').
      param('transformer-model', '', { 'url' => 'https://data.vespa-cloud.com/onnx_models/nomic-ai-modernbert-embed-base/model.onnx' }).
      param('transformer-token-type-ids').
      param('tokenizer-model', '', { 'url' => 'https://data.vespa-cloud.com/onnx_models/nomic-ai-modernbert-embed-base/tokenizer.json' }).
      param('transformer-output', 'token_embeddings').
      param('max-tokens', 8192).
      param('prepend', [ ComponentParam::new('query', 'search_query:', {}),
                         ComponentParam::new('document', 'search_document:', {}) ] )
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

  def voyage_lite_embedder_component
    Component.new('voyage-lite').
      type('voyage-ai-embedder').
      param('model', 'voyage-4-lite').
      param('api-key-secret-ref', 'voyage_api_key').
      param('dimensions', '1024')
  end

  def voyage_large_embedder_component
    Component.new('voyage-large').
      type('voyage-ai-embedder').
      param('model', 'voyage-4-large').
      param('api-key-secret-ref', 'voyage_api_key').
      param('dimensions', '1024')
  end

  def voyage_context_embedder_component
    Component.new('voyage-context-3').
      type('voyage-ai-embedder').
      param('model', 'voyage-context-3').
      param('api-key-secret-ref', 'voyage_api_key').
      param('dimensions', '1024')
  end

  def exception_embedder_component
    Component.new('exception-embedder').
      klass('ai.vespa.test.ExceptionThrowingEmbedder')
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
    start_vespa
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
    start_vespa
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
    start_vespa
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_huggingface_tokens
    verify_huggingface_embedding
  end

  def test_modernbert_embedding
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(nomic_modernbert_component).
            jvmoptions('-Xms3g -Xmx3g')).
        sd(selfdir + 'nomic-ai/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start_vespa
    feed_and_wait_for_docs('doc', 10, :file => selfdir + '10-docs.json')
    verify_embeddings_with('nomic-ai/expect.json', 'embedding', 'embedding', 'nomicmb')
    verify_embeddings_with('nomic-ai/expect.json', 'embedding_binarized', 'embedding_binarized_implicitly', 'nomicmb')
    verify_embeddings_with('nomic-ai/expect.json', 'embedding_binarized', 'embedding_binarized_explicitly', 'nomicmb')
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
    start_vespa
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
    start_vespa
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
    start_vespa
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_colbert_embedding_fp16
  end

  def test_huggingface_embedding_onnx_external_data
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(huggingface_tokenizer_component).
            component(huggingface_embedder_onnx_external_data_component).
            jvmoptions('-Xms4g -Xmx4g')).
        sd(selfdir + 'app_huggingface_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start_vespa
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "docs.json")
    verify_huggingface_external_data_embedding
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
    start_vespa
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
    start_vespa
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
    start_vespa
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "multivector-docs.json")
    verify_splade_multivector_embedding
  end

  def test_voyage_embedder
    set_description("Test Voyage AI embedder")

    # Fail immediately if API key is not available
    if ENV['VESPA_SECRET_VOYAGE_API_KEY'].nil? || ENV['VESPA_SECRET_VOYAGE_API_KEY'].empty?
      assert(false, "VESPA_SECRET_VOYAGE_API_KEY environment variable must be set")
    end

    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(voyage_lite_embedder_component).
            component(voyage_large_embedder_component).
            jvmoptions('-Xms2g -Xmx2g')).
        sd(selfdir + 'app_voyage_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start_vespa
    feed_and_wait_for_docs("doc", 10, :file => selfdir + "10-docs.json")
    verify_voyage_embedding
  end

  def test_voyage_contextualized_embeddings
    set_description("Test Voyage AI contextualized chunk embeddings")

    # Fail immediately if API key is not available
    if ENV['VESPA_SECRET_VOYAGE_API_KEY'].nil? || ENV['VESPA_SECRET_VOYAGE_API_KEY'].empty?
      assert(false, "VESPA_SECRET_VOYAGE_API_KEY environment variable must be set")
    end

    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(voyage_context_embedder_component).
            jvmoptions('-Xms2g -Xmx2g')).
        sd(selfdir + 'app_voyage_embedder_contextualized/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start_vespa
    feed_and_wait_for_docs("doc", 10, :file => selfdir + "10-docs-chunked.json")
    verify_voyage_contextualized_embeddings
  end

  def test_embedder_exceptions
    set_description("Test custom embedder OverloadException and TimeoutException handling")

    # Allow the expected RuntimeException in logs since we're testing exception handling
    add_expected_logged(/Embedder encountered an error - simulated generic exception/)

    add_bundle(selfdir + 'app_exception_embedder/components/ExceptionThrowingEmbedder.java')
    deploy_app(
      SearchApp.new.
        container(
          default_container_setup.
            component(exception_embedder_component)).
        sd(selfdir + 'app_exception_embedder/schemas/doc.sd').
        indexing_cluster('default').indexing_chain('indexing'))
    start_vespa

    verify_overload_exception
    verify_timeout_exception
    verify_generic_exception
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


  def check_val_by_idx(expected_v, actual_v, idx)
      expval = expected_v[idx]
      actval = actual_v[idx]
      assert((expval - actval).abs < 1e-5, "#{expval} != #{actval} at index #{idx}")
      #puts("OK[#{idx}]: #{expval}")
  end

  def check_prefix_suffix(expected_v, actual_v, fixlen)
    (1..fixlen).each { |i|
      check_val_by_idx(expected_v, actual_v, i-1)
      check_val_by_idx(expected_v, actual_v, -i)
    }
  end

  def verify_embeddings_with(savedFile, queryTensor, embeddingField, embedder = "modernbert")
    wanted = JSON.parse(File.read(selfdir + savedFile))
    wanted.each do |want|
      keyword = '"' + want['kw'] + '"'
      puts "Looking for #{keyword} using query tensor '#{queryTensor}' and field '#{embeddingField}'"
      qtext = want['qtext']

      # Verify embedding values *always using the 'embedding' tensor and field*
      q_emb = want['q_emb']
      d_emb = want['d_emb']
      yql = "select+*+from+sources+*+where+text+contains+#{keyword}"
      qi = "input.query(embedding)=embed(#{embedder},@myqtext)"
      result = search("?yql=#{yql}&#{qi}&myqtext=#{qtext}").json
      assert_equal(1, result['root']['children'].size)
      hitfields = result['root']['children'][0]['fields']
      queryFeature    = hitfields['summaryfeatures']['query(embedding)']
      documentFeature = hitfields['summaryfeatures']['attribute(embedding)']

      expected_length = 768
      assert_equal(expected_length, queryFeature['values'].length)
      assert_equal(expected_length, documentFeature['values'].length)

      dfv = documentFeature['values']
      check_prefix_suffix(d_emb, dfv, 5)

      qfv = queryFeature['values']
      check_prefix_suffix(q_emb, qfv, 5)

      # Verify that the expected match appears on top when searching with the given embeddingField
      expectedMostRelevant = want['expectedMostRelevant']
      yql = "select+*+from+sources+*+where+{targetHits:10}nearestNeighbor(#{embeddingField},#{queryTensor})"
      qi = "input.query(#{queryTensor})=embed(#{embedder},@myqtext)"
      result = search("?yql=#{yql}&#{qi}&myqtext=#{qtext}&ranking=#{embeddingField}")
      assert(result.hitcount >= 2)
      puts "Hit 1: #{result.hit[0]}"
      puts "Hit 2: #{result.hit[1]}"
      assert_equal(expectedMostRelevant, result.hit[0].field["documentid"])
    end
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

  def verify_huggingface_external_data_embedding
    expected_embedding = JSON.parse(File.read(selfdir + 'hf-external-data-expected-vector.json'))
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

  def verify_voyage_embedding
    # Test semantic search with 5 queries and verify the correct document is returned
    test_cases = [
      { query: "greeting message", expected_doc_id: "id:x:doc::1" },
      { query: "vessel for water transportation", expected_doc_id: "id:x:doc::2" },
      { query: "machine learning dimensionality reduction", expected_doc_id: "id:x:doc::5" },
      { query: "activation function in neural networks", expected_doc_id: "id:x:doc::6" },
      { query: "retro gaming console from the 80s", expected_doc_id: "id:x:doc::8" }
    ]

    # Test all three embedding types: float, binary int8, and regular int8
    embedding_configs = [
      { field: "embedding_float", query_tensor: "embedding_float", rank_profile: "float_angular", description: "float" },
      { field: "embedding_binary_int8", query_tensor: "embedding_binary_int8", rank_profile: "binary_int8", description: "binary int8" },
      { field: "embedding_int8", query_tensor: "embedding_int8", rank_profile: "int8_angular", description: "regular int8" }
    ]

    embedding_configs.each do |config|
      puts "\n=== Testing #{config[:description]} embedding (#{config[:field]}) ==="

      test_cases.each do |test_case|
        query_text = test_case[:query]
        expected_doc_id = test_case[:expected_doc_id]

        puts "\nQuery: '#{query_text}'"
        puts "Expected document: #{expected_doc_id}"

        # Perform nearest neighbor search using semantic embeddings
        # Query uses voyage-lite (fast), documents use voyage-large (high quality)
        yql = "select%20*%20from%20sources%20*%20where%20{targetHits:10}nearestNeighbor(#{config[:field]},#{config[:query_tensor]})"
        result = search("?yql=#{yql}&input.query(#{config[:query_tensor]})=embed(voyage-lite,@qtext)&qtext=#{CGI.escape(query_text)}&ranking=#{config[:rank_profile]}&format=json")

        # Verify we got results
        assert(result.hitcount > 0, "Query '#{query_text}' should return results for #{config[:description]} embedding")

        # Get the top hit document ID
        returned_doc_id = result.hit[0].field['documentid']

        puts "Returned document: #{returned_doc_id}"

        # Verify the returned document matches expected
        assert_equal(expected_doc_id, returned_doc_id,
          "Query '#{query_text}' expected #{expected_doc_id} but got #{returned_doc_id} for #{config[:description]} embedding")

        puts "✓ Correct document returned for #{config[:description]} embedding"
      end
    end
  end

  def verify_voyage_contextualized_embeddings
    # Test semantic search with 6 queries and verify the correct document is returned
    test_cases = [
      { query: "greeting message", expected_doc_id: "id:x:doc::1" },
      { query: "vessel for water transportation", expected_doc_id: "id:x:doc::2" },
      { query: "machine learning dimensionality reduction", expected_doc_id: "id:x:doc::5" },
      { query: "activation function in neural networks", expected_doc_id: "id:x:doc::6" },
      { query: "retro gaming console from the 80s", expected_doc_id: "id:x:doc::8" },
      { query: "American founding document charter of government", expected_doc_id: "id:x:doc::9" }
    ]

    puts "\n=== Testing contextualized chunk embeddings (chunk_embeddings) ==="

    test_cases.each do |test_case|
      query_text = test_case[:query]
      expected_doc_id = test_case[:expected_doc_id]

      puts "\nQuery: '#{query_text}'"
      puts "Expected document: #{expected_doc_id}"

      # Perform nearest neighbor search using contextualized embeddings
      yql = "select%20*%20from%20sources%20*%20where%20{targetHits:10}nearestNeighbor(chunk_embeddings,embedding_context)"
      result = search("?yql=#{yql}&input.query(embedding_context)=embed(voyage-context-3,@qtext)&qtext=#{CGI.escape(query_text)}&ranking=context_float&format=json")

      # Verify we got results
      assert(result.hitcount > 0, "Query '#{query_text}' should return results for contextualized embeddings")

      # Get the top hit document ID
      returned_doc_id = result.hit[0].field['documentid']

      puts "Returned document: #{returned_doc_id}"

      # Verify the returned document matches expected
      assert_equal(expected_doc_id, returned_doc_id,
        "Query '#{query_text}' expected #{expected_doc_id} but got #{returned_doc_id} for contextualized embeddings")

      puts "✓ Correct document returned for contextualized embeddings"
    end
  end

  def verify_overload_exception
    doc = Document.new("id:test:doc::overload").
      add_field("text", "This triggers an OVERLOAD exception")

    begin
      vespa.document_api_v1.put(doc, {:timeout => '10s'})
      flunk('Expected operation to fail with OverloadException')
    rescue HttpResponseError => e
      assert_equal(429, e.response_code, "Expected HTTP 429 for OverloadException")
    end
  end

  def verify_timeout_exception
    doc = Document.new("id:test:doc::timeout").
      add_field("text", "This triggers a TIMEOUT exception")

    begin
      vespa.document_api_v1.put(doc, {:timeout => '10s'})
      flunk('Expected operation to fail with TimeoutException')
    rescue HttpResponseError => e
      assert_equal(504, e.response_code, "Expected HTTP 504 for TimeoutException")
    end
  end

  def verify_generic_exception
    doc = Document.new("id:test:doc::error").
      add_field("text", "This triggers a generic ERROR exception")

    begin
      vespa.document_api_v1.put(doc, {:timeout => '10s'})
      flunk('Expected operation to fail with generic RuntimeException')
    rescue HttpResponseError => e
      assert_equal(500, e.response_code, "Expected HTTP 500 for generic RuntimeException")
    end
  end

  def start_vespa
    start(300) # Wait longer than default, download of models sometimes takes > 3 minutes
  end


end
