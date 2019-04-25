// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

/**
 * @author Tor Egge
 */
public class TensorInQueryBuilderSearcher extends Searcher {

    private static TensorType tt_dense_vector_5 = TensorType.fromSpec("tensor(x[5])");
    private static TensorType tt_dense_vector_10 = TensorType.fromSpec("tensor(x[10])");
    private static TensorType tt_dense_vector_25 = TensorType.fromSpec("tensor(x[25])");
    private static TensorType tt_dense_vector_50 = TensorType.fromSpec("tensor(x[50])");
    private static TensorType tt_dense_vector_100 = TensorType.fromSpec("tensor(x[100])");
    private static TensorType tt_dense_vector_250 = TensorType.fromSpec("tensor(x[250])");
    private static TensorType tt_dense_vector_500 = TensorType.fromSpec("tensor(x[500])");
    private static TensorType tt_sparse_vector_x = TensorType.fromSpec("tensor(x{})");
    private static TensorType tt_sparse_vector_y = TensorType.fromSpec("tensor(y{})");

    @Override
    public Result search(Query query, Execution execution) {
        considerInsertTensor(query, "q_dense_vector_5", "x", tt_dense_vector_5);
        considerInsertTensor(query, "q_dense_vector_10", "x", tt_dense_vector_10);
        considerInsertTensor(query, "q_dense_vector_25", "x", tt_dense_vector_25);
        considerInsertTensor(query, "q_dense_vector_50", "x", tt_dense_vector_50);
        considerInsertTensor(query, "q_dense_vector_100", "x", tt_dense_vector_100);
        considerInsertTensor(query, "q_dense_vector_250", "x", tt_dense_vector_250);
        considerInsertTensor(query, "q_dense_vector_500", "x", tt_dense_vector_500);
        considerInsertTensor(query, "q_sparse_vector_x", "x", tt_sparse_vector_x);
        considerInsertTensor(query, "q_sparse_vector_y", "y", tt_sparse_vector_y);
        return execution.search(query);
    }

    private static void considerInsertTensor(Query query, String tensorName, String tensorDimension, TensorType tensorType) {
        String tensorString = query.properties().getString(tensorName);
        if (tensorString != null) {
	    String[] tokens = tensorString.split(",");
	    Tensor.Builder tensorBuilder = Tensor.Builder.of(tensorType);
	    int label = 0;
	    for (String t: tokens) {
		tensorBuilder.cell().
		    label(tensorDimension, Integer.toString(label)).
		    value(Double.parseDouble(t));
		++label;
	    }
            query.getRanking().getFeatures().put("query(" + tensorName + ")",
						 tensorBuilder.build());
	}
    }

}
