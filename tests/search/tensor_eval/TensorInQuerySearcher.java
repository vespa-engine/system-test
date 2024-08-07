// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

/**
 * @author Geir Storli
 */
public class TensorInQuerySearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        considerInsertTensor(query, "age");
        considerInsertTensor(query, "sex");
        return execution.search(query);
    }

    private static void considerInsertTensor(Query query, String tensorDimension) {
        Object tensorLabel = query.properties().get("test." + tensorDimension);
        if (tensorLabel != null) {
	    TensorType.Builder type = new TensorType.Builder();
            type.mapped(tensorDimension);
            query.getRanking().getFeatures().put("query(" + tensorDimension + ")",
						 Tensor.Builder.of(type.build()).cell().label(tensorDimension, (String)tensorLabel).value(1.0).build());
        }
    }

}
