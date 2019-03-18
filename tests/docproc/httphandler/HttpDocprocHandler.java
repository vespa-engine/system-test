// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.google.inject.Inject;
import com.yahoo.component.provider.ComponentRegistry;
import com.yahoo.docproc.DocprocExecutor;
import com.yahoo.docproc.DocprocService;
import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.docproc.jdisc.DocumentProcessingHandler;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentTypeManager;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.yolean.Exceptions;
import com.yahoo.text.Utf8;
import com.yahoo.vespaxmlparser.VespaXMLDocumentReader;

import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import static com.yahoo.jdisc.http.HttpResponse.Status.*;

/**
 * @author Einar M R Rosenvinge
 */
public class HttpDocprocHandler extends ThreadedHttpRequestHandler {

    private static final String SERVICE_NAME = "default";
    private final DocumentProcessingHandler docprocHandler;

    @Inject
    public HttpDocprocHandler(DocumentProcessingHandler docprocHandler) {
        this(docprocHandler, Executors.newCachedThreadPool());
    }

    private HttpDocprocHandler(DocumentProcessingHandler docprocHandler, Executor executor) {
        super(executor);
        this.docprocHandler = docprocHandler;
    }

    @Override
    public HttpResponse handle(HttpRequest request) {
        DocprocExecutor executor = docprocHandler.getDocprocServiceRegistry().getComponent(SERVICE_NAME).getExecutor();
        DocumentTypeManager dtm = docprocHandler.getDocprocServiceRegistry()
                                                .getComponent(SERVICE_NAME)
                                                .getDocumentTypeManager();

        try {
            VespaXMLDocumentReader reader = new VespaXMLDocumentReader(request.getData(), dtm);
            Document doc = new Document(reader);

            Processing p = createProcessing(doc, SERVICE_NAME, docprocHandler.getDocprocServiceRegistry());
            DocumentProcessor.Progress progress = executor.process(p);

            while (progress != DocumentProcessor.Progress.DONE) {
                if (progress == DocumentProcessor.Progress.FAILED || progress == DocumentProcessor.Progress.PERMANENT_FAILURE) {
                    return new ErrorResponse("Processing failed.");
                }
                if (progress instanceof DocumentProcessor.LaterProgress) {
                    Thread.sleep(((DocumentProcessor.LaterProgress) progress).getDelay());
                }
                progress = executor.process(p);
            }

            return new DocprocResponse(p);
        } catch (Exception e) {
            return new ErrorResponse(e);
        }
    }

    private static Processing createProcessing(Document document, String serviceName, ComponentRegistry<DocprocService> docprocServiceRegistry) {
        Processing processing = new Processing();
        processing.addDocumentOperation(new DocumentPut(document));
        processing.setServiceName(serviceName);
        processing.setDocprocServiceRegistry(docprocServiceRegistry);
        return processing;
    }


    private static class DocprocResponse extends HttpResponse {
        private final Processing p;

        private DocprocResponse(Processing p) {
            super(OK);
            this.p = p;
        }

        @Override
        public void render(OutputStream stream) throws IOException {
            for (DocumentOperation op : p.getDocumentOperations()) {
                if (op instanceof DocumentPut) {
                    Document d = ((DocumentPut)op).getDocument();
                    stream.write(Utf8.toBytes(d.toXml()));
                    stream.write(Utf8.toBytes("\n"));
                }
                else {
                    stream.write(Utf8.toBytes("Cannot serialize '"));
                    stream.write(Utf8.toBytes(op.toString()));
                    stream.write(Utf8.toBytes("' as XML.\n"));
                }
            }
        }
    }

    private static class ErrorResponse extends HttpResponse {
        private final String errorMessage;

        private ErrorResponse(String errorMessage) {
            super(500);
            this.errorMessage = errorMessage;
        }

        private ErrorResponse(Exception e) {
            this(Exceptions.toMessageString(e));
        }

        @Override
        public void render(OutputStream stream) throws IOException {
            stream.write(Utf8.toBytes(errorMessage));
            stream.write(Utf8.toBytes("\n"));
        }

    }

}
