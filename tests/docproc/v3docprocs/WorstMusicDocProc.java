// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.document.*;
import com.yahoo.docproc.*;

public class WorstMusicDocProc extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                document.setFieldValue("title", "Worst music ever");
            }
        }
        return Progress.DONE;
    }

}
