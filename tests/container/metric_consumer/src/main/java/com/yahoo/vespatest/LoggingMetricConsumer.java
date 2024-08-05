// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.container.jdisc.MetricConsumerFactory;
import com.yahoo.jdisc.Metric;
import com.yahoo.jdisc.application.MetricConsumer;

import java.util.Map;
import java.util.logging.Logger;

/**
 * @author <a href="mailto:simon@yahoo-inc.com">Simon Thoresen Hult</a>
 * @version $Id$
 */
public class LoggingMetricConsumer implements MetricConsumerFactory {

    private final static Logger log = Logger.getLogger(LoggingMetricConsumer.class.getName());
    private final String name;
    
    public LoggingMetricConsumer(LoggingMetricConsumerConfig cfg) {
        name = cfg.name();
    }
    
    @Override
    public MetricConsumer newInstance() {
        return new MetricConsumer() {

            @Override
            public void set(String key, Number val, Metric.Context ctx) {
                log.info(name + "Consumer,set," + key + "," + val + "," + ctx);
            }

            @Override
            public void add(String key, Number val, Metric.Context ctx) {
                log.info(name + "Consumer,add," + key + "," + val + "," + ctx);
            }

            @Override
            public Metric.Context createContext(Map<String, ?> properties) {
                return new Metric.Context() {
                    
                    @Override
                    public String toString() {
                        return name + "Context";
                    }
                };
            }
        };
    }
}


