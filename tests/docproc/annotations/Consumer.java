// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.*;
import com.yahoo.document.annotation.Annotation;
import com.yahoo.document.annotation.SpanList;
import com.yahoo.document.annotation.SpanNode;
import com.yahoo.document.annotation.SpanTree;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.document.datatypes.Struct;

import java.util.Iterator;
import java.util.logging.Logger;

/**
 * @author Einar M R Rosenvinge
 */
public class Consumer extends DocumentProcessor {

	private static Logger log = Logger.getLogger(Consumer.class.getName());

	@Override
	public Progress process(Processing processing) {
		Iterator<DocumentOperation> it = processing.getDocumentOperations().iterator();
		while (it.hasNext()) {
			DocumentOperation op = it.next();
			if (!(op instanceof DocumentPut)) {
				it.remove();
				continue;
			}
			Document document = ((DocumentPut)op).getDocument();
			log.info("Getting 'content' field.");
			StringFieldValue content = (StringFieldValue) document.getFieldValue(document.getDataType().getField("content"));

			SpanTree tree = content.getSpanTree("meaningoflife");
			SpanList root = (SpanList) tree.getRoot();

			Iterator<SpanNode> childIterator = root.childIterator();
			SpanNode personSpan = childIterator.next();
			SpanNode artistSpan = childIterator.next();
			SpanNode dateSpan = childIterator.next();
			SpanNode placeSpan = childIterator.next();

			Annotation person = tree.iterator(personSpan).next();
			Struct personValue = (Struct) person.getFieldValue();
			System.err.println("Person is " + personValue.getField("name"));

			Annotation artist = tree.iterator(artistSpan).next();
			Struct artistValue = (Struct) artist.getFieldValue();
			System.err.println("Artist is " + artistValue.getFieldValue("name") + " who plays the " + artistValue.getFieldValue("instrument"));

			Annotation date = tree.iterator(dateSpan).next();
			Struct dateValue = (Struct) date.getFieldValue();
			System.err.println("Date is " + dateValue.getFieldValue("exacttime"));

			Annotation place = tree.iterator(placeSpan).next();
			Struct placeValue = (Struct) place.getFieldValue();
			System.err.println("Place is " + placeValue.getFieldValue("lat") + ";" + placeValue.getFieldValue("lon"));

			Annotation event = tree.iterator(root).next();
			Struct eventValue = (Struct) event.getFieldValue();
			System.err.println("Event is " + eventValue.getFieldValue("description") + " with " + eventValue.getFieldValue("person") + " and " + eventValue.getFieldValue("date") + " and " + eventValue.getFieldValue("place"));

			it.remove();
			log.info("Processed " + document);
		}
		log.info("Returning Progress.DONE");
		return Progress.DONE;
	}
}
