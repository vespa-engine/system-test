// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test.handler;

import ai.vespa.models.evaluation.ModelsEvaluator;
import ai.vespa.models.evaluation.FunctionEvaluator;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.serialization.JsonFormat;

import java.io.IOException;
import java.io.OutputStream;

public class TestModelsEvaluationHandler extends ThreadedHttpRequestHandler {

    private final ModelsEvaluator modelsEvaluator;

    public TestModelsEvaluationHandler(ModelsEvaluator modelsEvaluator, Context context) {
        super(context);
        this.modelsEvaluator = modelsEvaluator;
    }

    @Override
    public HttpResponse handle(HttpRequest request) {
        FunctionEvaluator evaluator = modelsEvaluator.evaluatorOf(request.getProperty("model"),
                                                                  request.getProperty("function"));
        if (request.getProperty("argumentName") != null)
            evaluator.bind(request.getProperty("argumentName"),
                           Tensor.from(evaluator.function().argumentTypes().get(request.getProperty("argumentName")),
				       request.getProperty("argumentValue")));
        return new RawResponse(JsonFormat.encode(evaluator.evaluate().sum()));
    }

    private static class RawResponse extends HttpResponse {

        private final byte[] data;

        RawResponse(byte[] data) {
            super(200);
            this.data = data;
        }

        @Override
        public String getContentType() {
            return "application/json";
        }

        @Override
        public void render(OutputStream outputStream) throws IOException {
            outputStream.write(data);
        }
    }

}
