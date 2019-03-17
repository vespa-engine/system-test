// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.filedistribution.fileacquirer.FileAcquirer;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.HitGroup;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;
import org.tensorflow.SavedModelBundle;
import org.tensorflow.Session;
import org.tensorflow.TensorFlow;

import java.io.File;
import java.nio.FloatBuffer;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;

public class TensorFlowSearcher extends Searcher {

    public static final Logger log = Logger.getLogger(TensorFlowSearcher.class.getName());

    private static final int classes = 10;
    private static final int pixels = 28*28;
    private static final String inputName = "input";
    private static final String operationName = "dnn/outputs/add";
    private static final String tensorFlowVersion = "1.12.0";

    private final SavedModelBundle tensorFlowModel;

    private void loadExtraContribModules() {
        String version = TensorFlow.version();
        log.info("TensorFlow version " + version);
        if ( ! tensorFlowVersion.equals(version)) {
            throw new IllegalStateException("Got tensorflow version " + version + " instead of expected " + tensorFlowVersion);
        }
        byte [] before = TensorFlow.registeredOpList();
        log.info("register op list contains " + before.length + " bytes");
        byte [] added = TensorFlow.loadLibrary("libtensorflow_contrib.so");
        if (added.length == 0) {
            throw new IllegalStateException("Only got " + added.length + " bytes from  TensorFlow.loadLibrary('libtensorflow_contrib.so'). Requires > 0");
        }
        log.info("Added libtensorflow_contrib.so: op list contains " + added.length + " bytes");
        byte [] after = TensorFlow.registeredOpList();
        log.info("register op list contains " + after.length + " bytes");
        if (after.length <= before.length) {
            throw new IllegalStateException("Nothing new contributed from TensorFlow.loadLibrary('libtensorflow_contrib.so')");
        }
    }
    public TensorFlowSearcher(FileAcquirer fileAcquirer, TfModelConfig config) {
        super();
        loadExtraContribModules();
        try {
            File tfModel = fileAcquirer.waitFor(config.model(), 5, TimeUnit.MINUTES);
            tensorFlowModel = SavedModelBundle.load(tfModel.getAbsolutePath(), "serve");
        } catch (InterruptedException e) {
            throw new RuntimeException("InterruptedException: ", e);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        Object classSelector = query.properties().get("class");
        if (classSelector != null) {
            long selector = Long.parseLong(classSelector.toString());
            Tensor tensor = Tensor.Builder.of(TensorType.fromSpec("tensor(d1[10])")).cell(1.0, selector).build();
            query.getRanking().getFeatures().put("query(class_selector)", tensor);
        }

        Result result = execution.search(query);
        execution.fill(result);

        if (classSelector != null) {
            int selector = Integer.parseInt(classSelector.toString());
            Object tfRankMethod = query.properties().get("tfrank");
            if (tfRankMethod == null || tfRankMethod.toString().equalsIgnoreCase("single")) {
                tensorFlowRankSingle(result, selector);
            } else if (tfRankMethod.toString().equalsIgnoreCase("multiple")) {
                tensorFlowRankMultiple(result, selector);
            }
        }
        return result;
    }

    private void tensorFlowRankSingle(Result result, int classSelector) {
        HitGroup hitGroup = result.hits();
        int count = hitGroup.getConcreteSize();
        for (int n = 0; n < count; ++n) {
            Hit hit = hitGroup.get(n);
            org.tensorflow.Tensor<?> placeholder = createPlaceholderSingle(hit);
            FloatBuffer fb = tensorFlowExecute(placeholder);
            addTensorFlowResult(hit, fb, 0, classSelector);
        }
    }

    private void tensorFlowRankMultiple(Result result, int classSelector) {
        org.tensorflow.Tensor<?> placeholder = createPlaceholderMultiple(result);
        FloatBuffer fb = tensorFlowExecute(placeholder);
        for (int n = 0; n < result.hits().getConcreteSize(); ++n) {
            addTensorFlowResult(result.hits().get(n), fb, n, classSelector);
        }
    }

    private void putCellValues(FloatBuffer fb, int start, Tensor tensor) {
        Iterator<Tensor.Cell> cellIterator = tensor.cellIterator();
        for (int i = start * pixels; i < (start + 1) * pixels; ++i) {
            fb.put(i, cellIterator.next().getValue().floatValue());
        }
    }

    private org.tensorflow.Tensor<?> createPlaceholderSingle(Hit hit) {
        Tensor image = (Tensor) hit.getField("image");
        FloatBuffer fb = FloatBuffer.allocate(1 * pixels);
        putCellValues(fb, 0, image);
        return org.tensorflow.Tensor.create(new long[]{ 1, pixels }, fb);
    }

    private org.tensorflow.Tensor<?> createPlaceholderMultiple(Result result) {
        HitGroup hitGroup = result.hits();
        int count = hitGroup.getConcreteSize();
        FloatBuffer fb = FloatBuffer.allocate(count * pixels);
        for (int n = 0; n < count; ++n) {
            Hit hit = hitGroup.get(n);
            Tensor image = (Tensor) hit.getField("image");
            putCellValues(fb, n, image);
        }
        return org.tensorflow.Tensor.create(new long[]{ count, pixels }, fb);
    }

    private void addTensorFlowResult(Hit hit, FloatBuffer fb, int n, int classSelector) {
        double tfRelevance = fb.get(n * classes + classSelector);
        hit.setField("tf_relevance", tfRelevance);
        hit.setField("relevance", hit.getRelevance().getScore());
        hit.removeField("image");
    }

    private FloatBuffer tensorFlowExecute(org.tensorflow.Tensor<?> placeholder) {
        Session.Runner runner = tensorFlowModel.session().runner();
        runner.feed(inputName, placeholder);
        List<org.tensorflow.Tensor<?>> results = runner.fetch(operationName).run();
        org.tensorflow.Tensor<?> tensor = results.get(0);
        FloatBuffer values = FloatBuffer.allocate(tensor.numElements());
        tensor.writeTo(values);
        return values;
    }

}
