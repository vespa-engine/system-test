// Copyright Vespa.ai. All rights reserved.
package com.yahoo.performance.searcher;

import com.yahoo.component.chain.dependencies.After;
import com.yahoo.component.chain.dependencies.Provides;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;
import com.yahoo.tensor.evaluation.MapEvaluationContext;
import com.yahoo.tensor.evaluation.Name;
import com.yahoo.tensor.evaluation.VariableTensor;
import com.yahoo.tensor.functions.Join;
import com.yahoo.tensor.functions.Reduce;
import com.yahoo.tensor.functions.TensorFunction;

import java.util.concurrent.ThreadLocalRandom;

@Provides("GroupingOperator")
@After("com.yahoo.prelude.searcher.ValidateSortingSearcher")
public class GarbageGeneratingSearcher extends Searcher {

    private static final int VECTOR_DIMENSIONS = 2048;
    private static final int MODEL_VECTOR_COUNT = 200;

    private static final TensorType VECTOR_TYPE =
            new TensorType.Builder(TensorType.Value.DOUBLE).indexed("x", VECTOR_DIMENSIONS).build();

    private static final TensorFunction<Name> DOT_PRODUCT_FUNCTION =
            new Reduce<>(
                    new Join<>(new VariableTensor<>("query", VECTOR_TYPE), new VariableTensor<>("model", VECTOR_TYPE),
                            (a, b) -> a * b),
                    Reduce.Aggregator.sum);

    @Override
    public Result search(Query query, Execution execution) {
        ThreadLocalRandom rng = ThreadLocalRandom.current();

        // Build a fresh query vector each request — creates short-lived Tensor.Builder and cell garbage
        Tensor queryVector = buildRandomVector(rng);

        // Compute dot product against each model vector, simulating math on 100 hits
        double sum = 0;
        MapEvaluationContext<Name> context = new MapEvaluationContext<>();
        context.put("query", queryVector);
        for (int i = 0; i < MODEL_VECTOR_COUNT; i++) {
            Tensor modelVector = buildRandomVector(rng);
            context.put("model", modelVector);
            sum += DOT_PRODUCT_FUNCTION.evaluate(context).asDouble();
        }

        Result result = new Result(query);
        result.setTotalHitCount(sum > 0 ? 1 : 0);
        return result;
    }

    private static Tensor buildRandomVector(ThreadLocalRandom rng) {
        Tensor.Builder builder = Tensor.Builder.of(VECTOR_TYPE);
        for (int i = 0; i < VECTOR_DIMENSIONS; i++) {
            builder.cell().label("x", i).value(rng.nextDouble());
        }
        return builder.build();
    }
}
