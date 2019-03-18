// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import ai.vespa.models.evaluation.ModelsEvaluator;
import com.yahoo.component.chain.dependencies.After;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.HitGroup;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;

@After("UserProfile")
public class TensorFlowStatelessEvaluation extends Searcher {

    private static final String MODEL_NAME = "blog_saved";
    private static final String FUNCTION_NAME = "serving_default";
    private static final String OUTPUT_NAME = "y";
    private static final String DOCUMENT_INPUT_NAME = "input_d";
    private static final String USER_INPUT_NAME = "input_u";

    private final ModelsEvaluator modelsEvaluator;

    private boolean logged = false;

    public TensorFlowStatelessEvaluation(ModelsEvaluator modelsEvaluator) {
        this.modelsEvaluator = modelsEvaluator;
    }

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        execution.fill(result);

	try {
	    if (query.properties().getString("ranking").equalsIgnoreCase("tensorflow_stateless_evaluation"))
		tensorFlowStatelessEvaluation(query, result);
	}
	catch (Exception e) {
	    if ( ! logged) {
		System.err.println(com.yahoo.yolean.Exceptions.toMessageString(e));
		e.printStackTrace(System.err);
		logged = true;
	    }
	}
        return result;
    }

    private void tensorFlowStatelessEvaluation(Query query, Result result) {
        Tensor user = query.getRanking().getFeatures().getTensor("query(user_item_cf)").orElseThrow(() -> new IllegalArgumentException("No user tensor found!"));
        for (Hit hit : result.hits().asList()) {
            Tensor document = (Tensor) hit.getField("user_item_cf");
            Tensor tensorResult = evaluateModel(user, document);
            setHitRelevance(hit, tensorResult);
        }
        result.hits().sort();
    }

    private void setHitRelevance(Hit hit, Tensor tensorResult) {
        double relevance = tensorResult.valueIterator().next();
        hit.setRelevance(relevance);
    }

    private Tensor evaluateModel(Tensor user, Tensor document) {
        return modelsEvaluator.evaluatorOf(MODEL_NAME, FUNCTION_NAME, OUTPUT_NAME)
                .bind(USER_INPUT_NAME, user)
                .bind(DOCUMENT_INPUT_NAME, document)
                .evaluate();
    }

}
