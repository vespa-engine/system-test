// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.example;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.FeatureData;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

/**
 * A searcher accessing tensors in the result
 */
public class SimpleSearcher extends Searcher {

	private static final double delta = 0.00001;

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
		FeatureData featureData = (FeatureData)hit.getField("summaryfeatures");

		Tensor indexedTensor = featureData.getTensor("rankingExpression(output_indexed_tensor");
		assertNotNull(indexedTensor);
		assertEquals(21.0, indexedTensor.sum(), delta);

		Tensor mappedTensor = featureData.getTensor("rankingExpression(output_mapped_tensor");
		assertNotNull(mappedTensor);
		assertEquals(3.0, mappedTensor.sum(), delta);

		Tensor mappedTensor = featureData.getTensor("rankingExpression(output_mixed_tensor");
		assertNotNull(mappedTensor);
		assertEquals(6.0, mappedTensor.sum(), delta);
	}

}
