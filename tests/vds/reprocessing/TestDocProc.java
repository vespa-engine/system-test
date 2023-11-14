// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.document.*;
import com.yahoo.document.datatypes.*;
import com.yahoo.docproc.*;

public class TestDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut documentPut) {
        Document document = documentPut.getDocument();
        IntegerFieldValue oldValue = (IntegerFieldValue)document.getFieldValue("year");
        document.setFieldValue("year", new IntegerFieldValue(oldValue.getInteger() + 1));
        System.out.println("Processed " + document);
    }

}
