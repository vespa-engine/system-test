// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtException;
import ai.onnxruntime.OrtSession;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.filedistribution.fileacquirer.FileAcquirer;

import java.io.File;
import java.util.Map;
import java.util.concurrent.TimeUnit;

public class OnnxSearcher extends Searcher {

    private File modelFiles;
    private OrtEnvironment env;
    private OrtSession session;

    public OnnxSearcher(FileAcquirer fileAcquirer, ModelsConfig config) {
        try {
            modelFiles = fileAcquirer.waitFor(config.models(), 5, TimeUnit.MINUTES);
            env = OrtEnvironment.getEnvironment();
            session = env.createSession(modelFiles.getAbsolutePath(), new OrtSession.SessionOptions());
        } catch (InterruptedException e) {
            throw new RuntimeException("InterruptedException: ", e);
        } catch (OrtException e) {
            throw new RuntimeException("OrtException: ", e);
        }
    }

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        try {
            var input1 = OnnxTensor.createTensor(env, new float[] {2});
            var input2 = OnnxTensor.createTensor(env, new float[] {3});
            var inputs = Map.of("input1",input1,"input2",input2);
            try (var results = session.run(inputs)) {
                float[] output = (float[]) results.get(0).getValue();

                Hit hit = new Hit("searcher");
                hit.setField("model", "add");
                hit.setField("result", output[0]);
                result.hits().add(hit);
            }
        } catch (OrtException e) {
            e.printStackTrace();
        }
        return result;
    }

}
