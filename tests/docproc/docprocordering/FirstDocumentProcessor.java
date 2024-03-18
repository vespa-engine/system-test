// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.Processing;
import com.yahoo.document.DataType;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.datatypes.Array;
import com.yahoo.document.datatypes.StringFieldValue;

import com.yahoo.vespatest.order.OrderDocumentProcessor;

/**
 * @author Einar M R Rosenvinge
 */
public class FirstDocumentProcessor extends OrderDocumentProcessor {

    private static final String fieldName = "stringarray";

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                Array<StringFieldValue> stringArray;
                if (document.getFieldValue(fieldName) == null)
                    stringArray = new Array<>(DataType.getArray(DataType.STRING));
                else
                    stringArray = (Array<StringFieldValue>) document.getFieldValue(fieldName);

                assertArraySize(stringArray, 0);

                stringArray.add(new StringFieldValue("first"));
                document.setFieldValue(fieldName, stringArray);
            }
        }
        return Progress.DONE;
    }

}
