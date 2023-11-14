// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class OneToManyDocumentsProcessor extends DocumentProcessor {

	private final DocumentTypeManager types;

	public OneToManyDocumentsProcessor(DocumentTypeManager types) {
		this.types = types;
	}

	@Override
	public Progress process(Processing processing) {
		List<DocumentOperation> docs = processing.getDocumentOperations();
		docs.clear();
		DocumentType type = types.getDocumentType("worst");
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:er:bra")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:er:ja")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:trallala")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:hahahhaa")));
		return Progress.DONE;
	}

}
