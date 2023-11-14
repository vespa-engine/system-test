// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;

public class LoggerHandler extends AbstractRequestHandler {

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        org.apache.commons.logging.LogFactory.getLog("jcl").info("hello from jcl");
        org.apache.log4j.Logger.getLogger("log4j").info("hello from log4j");
        org.slf4j.LoggerFactory.getLogger("slf4j").info("hello from slf4j");
        java.util.logging.Logger.getLogger("jdk").info("hello from jdk");

        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write("hello from handler");
        writer.close();
        return null;
    }

}
