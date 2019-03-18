// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.component.chain.dependencies.After;
import com.yahoo.filedistribution.fileacquirer.FileAcquirer;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.HitGroup;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import org.tensorflow.SavedModelBundle;
import org.tensorflow.Session;

import java.io.File;
import java.nio.FloatBuffer;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;

@After("UserProfile")
public class TensorFlowSearcher extends Searcher {

    private static final int cfLength = 128;
    private static final String operationName = "y";

    private final SavedModelBundle tensorFlowModel;

    public TensorFlowSearcher(FileAcquirer fileAcquirer, TfModelConfig config) {
        super();
        try {
            File tfModel = fileAcquirer.waitFor(config.model(), 5, TimeUnit.MINUTES);
            tensorFlowModel = SavedModelBundle.load(tfModel.getAbsolutePath(), "serve");
        } catch (InterruptedException e) {
            throw new RuntimeException("InterruptedException: ", e);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        execution.fill(result);

        String ranking = query.properties().getString("ranking");
        if (ranking.equalsIgnoreCase("tensorflow_single")) {
            tensorFlowRankSingle(query, result);
        } else if (ranking.equalsIgnoreCase("tensorflow_multiple")) {
            tensorFlowRankMultiple(query, result);
        }

        return result;
    }

    private void tensorFlowRankSingle(Query query, Result result) {
        HitGroup hitGroup = result.hits();
        int count = hitGroup.getConcreteSize();
        try (org.tensorflow.Tensor<?> userPlaceholder = createUserPlaceholderSingle(query)) {
            for (int n = 0; n < count; ++n) {
                Hit hit = hitGroup.get(n);
                try (org.tensorflow.Tensor<?> docPlaceholder = createDocumentPlaceholderSingle(hit)) {
                    FloatBuffer fb = tensorFlowExecute(userPlaceholder, docPlaceholder);
                    addTensorFlowResult(hit, fb, 0);
                }
            }
        }
        result.hits().sort();
    }

    private void tensorFlowRankMultiple(Query query, Result result) {
        try (org.tensorflow.Tensor<?> userPlaceholder = createUserPlaceholderMultiple(query, result)) {
            try (org.tensorflow.Tensor<?> docPlaceholder = createDocumentPlaceholderMultiple(result)) {
                FloatBuffer fb = tensorFlowExecute(userPlaceholder, docPlaceholder);
                for (int n = 0; n < result.hits().getConcreteSize(); ++n) {
                    addTensorFlowResult(result.hits().get(n), fb, n);
                }
            }
        }
        result.hits().sort();
    }

    private void putCellValues(FloatBuffer fb, int start, Tensor tensor) {
        Iterator<Tensor.Cell> cellIterator = tensor.cellIterator();
        for (int i = start * cfLength; i < (start + 1) * cfLength; ++i) {
            fb.put(i, cellIterator.next().getValue().floatValue());
        }
    }

    private org.tensorflow.Tensor<?> createUserPlaceholderSingle(Query query) {
        Tensor user = query.getRanking().getFeatures().getTensor("query(user_item_cf)").orElseThrow(() -> new IllegalArgumentException("No user tensor found!"));
        FloatBuffer fb = FloatBuffer.allocate(1 * cfLength);
        putCellValues(fb, 0, user);
        return org.tensorflow.Tensor.create(new long[]{ 1, cfLength }, fb);
    }

    private org.tensorflow.Tensor<?> createDocumentPlaceholderSingle(Hit hit) {
        Tensor doc = (Tensor) hit.getField("user_item_cf");
        FloatBuffer fb = FloatBuffer.allocate(1 * cfLength);
        putCellValues(fb, 0, doc);
        return org.tensorflow.Tensor.create(new long[]{ 1, cfLength }, fb);
    }

    private org.tensorflow.Tensor<?> createUserPlaceholderMultiple(Query query, Result result) {
        Tensor user = query.getRanking().getFeatures().getTensor("query(user_item_cf)").orElseThrow(() -> new IllegalArgumentException("No user tensor found!"));
        int count = result.hits().getConcreteSize();
        FloatBuffer fb = FloatBuffer.allocate(count * cfLength);
        for (int n = 0; n < count; ++n) {
            putCellValues(fb, n, user);
        }
        return org.tensorflow.Tensor.create(new long[]{ count, cfLength }, fb);
    }

    private org.tensorflow.Tensor<?> createDocumentPlaceholderMultiple(Result result) {
        HitGroup hitGroup = result.hits();
        int count = hitGroup.getConcreteSize();
        FloatBuffer fb = FloatBuffer.allocate(count * cfLength);
        for (int n = 0; n < count; ++n) {
            Hit hit = hitGroup.get(n);
            Tensor doc = (Tensor) hit.getField("user_item_cf");
            putCellValues(fb, n, doc);
        }
        return org.tensorflow.Tensor.create(new long[]{ count, cfLength }, fb);
    }

    private void addTensorFlowResult(Hit hit, FloatBuffer fb, int n) {
        double tfRelevance = fb.get(n);
        hit.setRelevance(tfRelevance);
    }

    private FloatBuffer tensorFlowExecute(org.tensorflow.Tensor<?> user, org.tensorflow.Tensor<?> doc) {
        Session.Runner runner = tensorFlowModel.session().runner();
        runner.feed("input_u", user);
        runner.feed("input_d", doc);
        List<org.tensorflow.Tensor<?>> results = null;
        try {
            results = runner.fetch(operationName).run();
            org.tensorflow.Tensor<?> tensor = results.get(0);
            FloatBuffer values = FloatBuffer.allocate(tensor.numElements());
            tensor.writeTo(values);
            return values;
        } finally {
            if (results != null) {
                for (org.tensorflow.Tensor<?> tensor : results) {
                    tensor.close();
                }
            }
        }
    }

}
