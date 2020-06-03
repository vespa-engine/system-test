package com.yahoo.performance.handler;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.ResourceReference;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.lang.Runnable;

public class AsyncHelloWorldHandler extends AbstractRequestHandler {
    private ExecutorService executor = Executors.newCachedThreadPool();
    private static class EchoTask implements Runnable {
        private final ResourceReference requestReference;
        private final FastContentWriter writer;
        EchoTask(Request request, FastContentWriter w) {
            this.requestReference = request.refer();
            this.writer = w;
        }
        @Override
        public void run() {
            try {
               writer.write("Hello, world!");
               writer.close();
            } catch (Exception ignored) {
            } finally {
               requestReference.close();
            }
      }
    }
    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        ContentChannel channel = ResponseDispatch.newInstance(Response.Status.OK).connect(handler);
        executor.execute(new EchoTask(request, new FastContentWriter(channel)));
        return null;
    }
}
