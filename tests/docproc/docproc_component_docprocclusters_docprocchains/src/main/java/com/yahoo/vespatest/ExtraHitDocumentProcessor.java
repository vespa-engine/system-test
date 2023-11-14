// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.component.ComponentId;
import com.yahoo.vespatest.ExtraHitConfig;
import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.datatypes.StringFieldValue;

public class ExtraHitDocumentProcessor extends DocumentProcessor {
    private final String title;

    public ExtraHitDocumentProcessor(ExtraHitConfig config) {
        title = config.exampleString();
    }

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut) op).getDocument();
                document.setFieldValue("title", new StringFieldValue(title));
            }
        }
        return Progress.DONE;
    }
}
