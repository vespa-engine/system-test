package com.yahoo.vespatest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;

import java.io.OutputStream;
import java.io.PrintStream;
import java.util.concurrent.Executor;

public class TensorEvalHandler extends ThreadedHttpRequestHandler {

    @Inject
    public TensorEvalHandler(Executor executor, Metric metric) {
        super(executor, metric);
    }

    @Override
    public HttpResponse handle(HttpRequest request) {
        TensorFunctionBenchmark.run_all(2000, 1);
        
        return new HttpResponse(200) {
            @Override
            public void render(OutputStream outputStream) {
                PrintStream out = new PrintStream(outputStream);
                out.print("OK");
                out.flush();
            }
        };
    }
}
