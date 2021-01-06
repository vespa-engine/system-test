// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import ai.vespa.models.evaluation.ModelsEvaluator;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.HitGroup;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorAddress;

import com.yahoo.filedistribution.fileacquirer.FileAcquirer;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.HitGroup;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

import java.io.File;
import java.nio.FloatBuffer;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;

public class TensorFlowStatelessEvaluation extends Searcher {

    private static final String MODEL_NAME = "mnist_saved";
    private static final String FUNCTION_NAME = "serving_default.y";
    private static final String INPUT_NAME = "input";

    private final ModelsEvaluator modelsEvaluator;

    public TensorFlowStatelessEvaluation(ModelsEvaluator modelsEvaluator) {
        super();
        this.modelsEvaluator = modelsEvaluator;
    }

    @Override
    public Result search(Query query, Execution execution) {
        Object classSelector = query.properties().get("class");
        long selector = Long.parseLong(classSelector.toString());
        Tensor tensor = Tensor.Builder.of(TensorType.fromSpec("tensor(d1[10])")).cell(1.0, selector).build();
        query.getRanking().getFeatures().put("query(class_selector)", tensor);
        Result result = execution.search(query);
        execution.fill(result);
        tensorFlowStatelessEvaluation(result, selector);
        return result;
    }

    private void tensorFlowStatelessEvaluation(Result result, long classSelector) {
        for (Hit hit : result.hits()) {
            Tensor image = (Tensor) hit.getField("image");
            Tensor tensorResult  = evaluateModel(image);
            setHitRelevance(hit, tensorResult, classSelector);
        }
    }

    private void setHitRelevance(Hit hit, Tensor tensorResult, long classSelector) {
        double tfRelevance = tensorResult.get(TensorAddress.of(0, classSelector));
        hit.setField("tf_relevance", tfRelevance);
        hit.setField("relevance", hit.getRelevance().getScore());
        hit.removeField("image");
    }

    private Tensor evaluateModel(Tensor image) {
        return modelsEvaluator.evaluatorOf(MODEL_NAME, FUNCTION_NAME).bind(INPUT_NAME, image).evaluate();
    }

}
