package com.yahoo.performance.handler;

import com.google.inject.Inject;
import com.yahoo.container.handler.threadpool.ContainerThreadPool;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;

import java.io.OutputStream;
import java.io.PrintStream;
import java.util.concurrent.Executor;

/**
 * @author bjorncs
 */
public class HelloWorldHandler extends ThreadedHttpRequestHandler {

    @Inject
    public HelloWorldHandler(ContainerThreadPool pool, Metric metric) {
        super(pool, metric);
    }

    @Override
    public HttpResponse handle(HttpRequest request) {
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
