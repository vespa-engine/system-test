// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.example;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.FeatureData;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;

/**
 * A searcher accessing tensors in the result
 */
public class TensorAccessingSearcher extends Searcher {

    @Override
	public Result search(Query query, Execution execution) {
        Result result = execution.search(query); // Pass on to the next searcher to get results
        for (Hit hit : result.hits().asList()) {
            if (hit.isMeta()) continue;
            assertHasTensors(hit);
        }
        return result;
    }

    private void assertHasTensors(Hit hit) {
        FeatureData featureData = hit.features();
        assertTensorSum("output_indexed_tensor", 21.0, featureData);
        assertTensorSum("output_mapped_tensor", 3.0, featureData);
        assertTensorSum("output_mixed_tensor", 6.0, featureData);
    }

    private void assertTensorSum(String name, double expectedSum, FeatureData featureData) {
        Tensor tensor = featureData.getTensor(name);
        if (tensor == null)
            throw new RuntimeException("Tensor '" + name + "' is missing");
        if (tensor.sum().asDouble() - expectedSum > 0.00001)
            throw new RuntimeException("Tensor '" + name + "' is " + tensor + " with sum " + tensor.sum().asDouble() + " but expected the sum to be " + expectedSum);
    }

}
