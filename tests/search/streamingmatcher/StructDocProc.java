package com.yahoo.vespatest;

import com.yahoo.document.ArrayDataType;
import com.yahoo.document.DataType;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentTypeManager;
import com.yahoo.document.Field;
import com.yahoo.document.datatypes.*;
import com.yahoo.docproc.*;
import java.util.ArrayList;
import java.util.List;

public class StructDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut documentPut) {
        Document document = documentPut.getDocument();
        System.out.println("Inside StructDocProc");

        Array<StringFieldValue> as1 = new Array<StringFieldValue>(new ArrayDataType(DataType.STRING));
        as1.add(new StringFieldValue("per"));
        as1.add(new StringFieldValue("paal"));

        Array<LongFieldValue> al1 = new Array<LongFieldValue>(new ArrayDataType(DataType.LONG));
        al1.add(new LongFieldValue(11223344556677881l));
        al1.add(new LongFieldValue(11223344556677883l));

        { // set ssf1
            StructuredFieldValue ssf1 = (StructuredFieldValue)document.getFieldValue(document.getField("ssf1"));
            ssf1.setFieldValue("as1", as1);
            ssf1.setFieldValue("al1", al1);
        }

        { // set ssf2
            StructuredFieldValue ssf2 = (StructuredFieldValue)document.getFieldValue(document.getField("ssf2"));
            ssf2.setFieldValue("as1", as1);
            ssf2.setFieldValue("al1", al1);
        }

        { // set ssf4
            StructuredFieldValue ssf4 = (StructuredFieldValue)document.getFieldValue(document.getField("ssf4"));
            ssf4.setFieldValue("as1", as1);
            ssf4.setFieldValue("al1", al1);
        }

        { // set ssf5
            StructuredFieldValue ssf5 = new Struct(document.getField("ssf5").getDataType());
            document.setFieldValue("ssf5", ssf5);
            StructuredFieldValue nss1 = new Struct(ssf5.getField("nss1").getDataType());
            ssf5.setFieldValue("nss1", nss1);
            nss1.setFieldValue("s1", "string espa\u00f1a ssf5.nss1.s1");
            nss1.setFieldValue("l1", 1122334455667788995l);
            nss1.setFieldValue("i1", 5);
            nss1.setFieldValue("d1", 85.79);
            nss1.setFieldValue("as1", as1);
            nss1.setFieldValue("al1", al1);
            StringFieldValue s2 = new StringFieldValue("string espa\u00f1a ssf5.s2");
            ssf5.setFieldValue("s2", s2);
        }

        { // set ssf6
            StructuredFieldValue ssf6 = new Struct(document.getField("ssf6").getDataType());
            document.setFieldValue("ssf6", ssf6);
            StructuredFieldValue nss1 = new Struct(ssf6.getField("nss1").getDataType());
            ssf6.setFieldValue("nss1", nss1);
            nss1.setFieldValue("s1", "string espa\u00f1a ssf6.nss1.s1");
            nss1.setFieldValue("l1", 1122334455667788996l);
            nss1.setFieldValue("i1", 6);
            nss1.setFieldValue("d1", 86.79);
            nss1.setFieldValue("as1", as1);
            nss1.setFieldValue("al1", al1);
            StringFieldValue s2 = new StringFieldValue("string espa\u00f1a ssf6.s2");
            ssf6.setFieldValue("s2", s2);
        }

        { // set ssf8
            StructuredFieldValue ssf8 = new Struct(document.getField("ssf8").getDataType());
            document.setFieldValue("ssf8", ssf8);
            StructuredFieldValue nss1 = new Struct(ssf8.getField("nss1").getDataType());
            ssf8.setFieldValue("nss1", nss1);
            nss1.setFieldValue("s1", "string espa\u00f1a ssf8.nss1.s1");
            nss1.setFieldValue("l1", 1122334455667788998l);
            nss1.setFieldValue("i1", 8);
            nss1.setFieldValue("d1", 88.79);
            nss1.setFieldValue("as1", as1);
            nss1.setFieldValue("al1", al1);
            StringFieldValue s2 = new StringFieldValue("string espa\u00f1a ssf8.s2");
            ssf8.setFieldValue("s2", s2);
        }

        { // set asf1
            Array<Struct> asf1 = (Array<Struct>)document.getFieldValue(document.getField("asf1"));
            asf1.get(0).setFieldValue("as1", as1);
            asf1.get(0).setFieldValue("al1", al1);
            asf1.get(1).setFieldValue("as1", as1);
            asf1.get(1).setFieldValue("al1", al1);
        }

        { // set asf2
            Array<Struct> asf2 = (Array<Struct>)document.getFieldValue(document.getField("asf2"));
            asf2.get(0).setFieldValue("as1", as1);
            asf2.get(0).setFieldValue("al1", al1);
            asf2.get(1).setFieldValue("as1", as1);
            asf2.get(1).setFieldValue("al1", al1);
        }
    }
}
