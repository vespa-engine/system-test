// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class OneToManyDocumentsSomeInSameBucketProcessor extends DocumentProcessor {

	private final DocumentTypeManager types;

	public OneToManyDocumentsSomeInSameBucketProcessor(DocumentTypeManager types) {
		this.types = types;
	}

	@Override
	public Progress process(Processing processing) {
		List<DocumentOperation> docs = processing.getDocumentOperations();
		docs.clear();
		DocumentType type = types.getDocumentType("worst");
		docs.add(new DocumentPut(new Document(type, "id:123456:worst:n=7890:balla:er:bra")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:er:ja")));
		docs.add(new DocumentPut(new Document(type, "id:567890:worst:n=1234:a")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:hahahhaa")));
		docs.add(new DocumentPut(new Document(type, "id:123456:worst:n=7890:a:a")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:aa")));
		docs.add(new DocumentPut(new Document(type, "id:567890:worst:n=1234:balla:ala")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:sdfgsaa")));
		docs.add(new DocumentPut(new Document(type, "id:123456:worst:n=7890:balla:tralsfa")));
		docs.add(new DocumentPut(new Document(type, "id:jalla:worst::balla:dfshaa")));
		return Progress.DONE;
	}

}
