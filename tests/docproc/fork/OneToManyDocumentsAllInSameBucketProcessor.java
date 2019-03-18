// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class OneToManyDocumentsAllInSameBucketProcessor extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        DocumentType type = processing.getService().getDocumentTypeManager().getDocumentType("worst");
        List<DocumentOperation> docs = processing.getDocumentOperations();
        docs.clear();
        docs.add(new DocumentPut(new Document(type, "id:123456:worst:n=11111:jalla:er:bra")));
        docs.add(new DocumentPut(new Document(type, "id:123456:worst:n=11111:jalla:trallala")));
        docs.add(new DocumentPut(new Document(type, "id:123456:worst:n=11111:jalla:a")));
        return Progress.DONE;
    }

}
