// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.docproc.*;

public class BananaDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut documentPut) {
        Document document = documentPut.getDocument();
        document.setFieldValue("title", document.getFieldValue("title").toString() + " Banana");
    }

}
