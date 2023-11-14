// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package concretedocs;

import com.yahoo.document.*;
import com.yahoo.document.annotation.SpanTree;
import com.yahoo.docproc.*;
import com.yahoo.concretedocs.Vehicle;
import com.yahoo.concretedocs.Ship;
import com.yahoo.concretedocs.annotation.Place;
import com.yahoo.concretedocs2.Disease;

/**
 * An example document processor using concrete doc types.
 *
 * @author vegardh
 */
public class ConcreteDocDocProc extends DocumentProcessor {

    public Progress process(Processing processing) {
        // Just checking this type is available
        Ship ship = new Ship(new DocumentId("id:ship:ship::0")).setYear(2012);
        if (!(ship.getYear()==2012)) return Progress.FAILED;

        Document document = ((DocumentPut)processing.getDocumentOperations().get(0)).getDocument();
        if (document instanceof Vehicle) return processVehicle((Vehicle)document);
        if (document instanceof Disease) return processDisease((Disease)document);
        return Progress.FAILED;
    }

    private Progress processVehicle(Vehicle v) {
        System.out.println("Concrete processing vehicle, year was "+v.getYear());
        SpanTree regTree = new SpanTree("default");
        Place p = new Place();
        p.setLat(9l);
        p.setLon(10l);
        v.setYear(2013);
        regTree.annotate(p);
        v.regSpanTrees().put("default", regTree);
        v.setLocation(new Vehicle.Position().setX(2).setY(3));
        return Progress.DONE;
    }

    private Progress processDisease(Disease d) {
        System.out.println("Concrete processing disease,  symptom was "+d.getSymptom());
        d.setSymptom("Paralysis");
        return Progress.DONE;
    }

}
