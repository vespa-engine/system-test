// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.Processing;
import com.yahoo.document.DataType;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.datatypes.Array;
import com.yahoo.document.datatypes.FieldValue;
import com.yahoo.document.datatypes.StringFieldValue;

import com.yahoo.vespatest.order.OrderDocumentProcessor;

/**
 * @author Einar M R Rosenvinge
 */
public class FirstDocumentProcessor extends OrderDocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                FieldValue stringArray = document.getFieldValue("stringarray");
                if (stringArray == null)
                    stringArray = new Array<>(DataType.STRING);

                assertArraySize(stringArray, 0);

                ((Array<StringFieldValue>) stringArray).add(new StringFieldValue("first"));
            }

        }
        return Progress.DONE;
    }

}
