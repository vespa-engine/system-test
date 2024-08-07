// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import ai.vespa.models.evaluation.FunctionEvaluator;
import ai.vespa.models.evaluation.Model;
import ai.vespa.models.evaluation.ModelsEvaluator;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;

public class OnnxEvaluator extends Searcher {

    private ModelsEvaluator evaluator;

    public OnnxEvaluator(ModelsEvaluator evaluator) {
        this.evaluator = evaluator;
    }

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);

        Model mul = evaluator.models().get("mul");
        FunctionEvaluator evaluator = mul.evaluatorOf();

        Tensor input1 = Tensor.from("tensor<float>(d0[1]):[2]");
        Tensor input2 = Tensor.from("tensor<float>(d0[1]):[3]");
        Tensor output = evaluator.bind("input1", input1).bind("input2", input2).evaluate();

        Hit hit = new Hit("evaluator");
        hit.setField("model", "mul");
        hit.setField("result", output.sum().asDouble());
        result.hits().add(hit);

        return result;

    }
}
