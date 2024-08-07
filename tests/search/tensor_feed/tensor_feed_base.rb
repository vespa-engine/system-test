# Copyright Vespa.ai. All rights reserved.

module TensorFeedTestBase

  def search_result_document(query, exp_relevancy)
    result = search(query)
    assert_relevancy(result, exp_relevancy)
    extract_docs(result.json)[0]
  end

  def get_result_document(doc_id)
    result = vespa.document_api_v1.get(doc_id, {"format.tensors"=>"long"})
    {"fields" => result.fields}
  end

  def extract_docs(json_response)
    docs = json_response['root']['children']
    docs.sort! { |x,y| x['id'] <=> y['id'] }
    docs
  end

  def extract_visit_docs(json_response)
    docs = json_response['documents']
    docs.sort! { |x,y| x['id'] <=> y['id'] }
    docs
  end

  def assert_tensor_field(exp_cells, doc, field_name = 'my_tensor')
    tensor_field = get_tensor_field(doc, field_name)
    act_cells = tensor_field['cells']
    # From test_base.rb
    assert_tensor_cells(exp_cells, act_cells)
  end

  def get_tensor_field(doc, field_name = 'my_tensor')
    doc['fields'][field_name]
  end

end
