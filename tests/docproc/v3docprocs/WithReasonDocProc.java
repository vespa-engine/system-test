// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentOperation;
import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;

public class WithReasonDocProc extends DocumentProcessor {

    private static final String failedId = "id:test:worst::42";

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                if (document.getId().toString().equals(failedId)) {
                    return Progress.FAILED.withReason("Some detailed failure reason");
                }
            }
        }

        return Progress.DONE;
    }

}
