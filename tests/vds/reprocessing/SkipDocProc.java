// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.document.*;
import com.yahoo.docproc.*;
import java.util.Iterator;

public class SkipDocProc extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        Iterator<DocumentOperation> it = processing.getDocumentOperations().iterator();
        while (it.hasNext()) {
            DocumentOperation document = it.next();
            it.remove();
            System.out.println("Processed " + document);
        }
        return Progress.DONE;
    }
}
