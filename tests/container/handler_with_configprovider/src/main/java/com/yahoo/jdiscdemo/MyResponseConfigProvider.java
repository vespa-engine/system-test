// Copyright Vespa.ai. All rights reserved.
package com.yahoo.jdiscdemo;

import com.yahoo.container.di.componentgraph.Provider;

/**
 * Translates ResponseConfig (cloud config) to MyResponseConfig (proprietary config)
 * @author gv
 */
public class MyResponseConfigProvider implements Provider<MyResponseConfig> {
    private final MyResponseConfig myResponseConfig;

    public MyResponseConfigProvider(ResponseConfig config) {
        myResponseConfig = new MyResponseConfig();
        myResponseConfig.setResponse(config.response());

        System.out.println(">>> Provider set response: " + config.response());
    }

    @Override
    public MyResponseConfig get() {
        return myResponseConfig;
    }

    @Override
        public void deconstruct() {}
}
