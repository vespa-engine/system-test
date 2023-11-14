// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.Field;
import com.yahoo.docproc.SimpleDocumentProcessor;

public class AppleDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut documentPut) {
        Document document = documentPut.getDocument();
        Field apple = document.getField("apple");
        if (apple==null) throw new IllegalStateException("getField returned null");

        document.setFieldValue("apple", document.getFieldValue("apple").toString() + " Apple");
        System.out.println("APPLE: "+document.getFieldValue("apple"));
    }

}
