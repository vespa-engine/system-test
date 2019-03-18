// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class OneToManyDocumentsProcessor extends DocumentProcessor {

    @Override
	public Progress process(Processing processing) {
		DocumentType type = processing.getService().getDocumentTypeManager().getDocumentType("worst");
		List<DocumentOperation> docs = processing.getDocumentOperations();
		docs.clear();
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:er:bra")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:er:ja")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:trallala")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:hahahhaa")));
		return Progress.DONE;
	}

}
