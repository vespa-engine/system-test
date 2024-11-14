// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.query.profile;

import com.yahoo.config.subscription.ConfigGetter;
import com.yahoo.search.query.profile.config.QueryProfileConfigurer;
import com.yahoo.search.query.profile.config.QueryProfilesConfig;
import org.junit.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

/**
 * Compilation efficiency.
 *
 * @author jonmv
 */
public class QueryProfileCompilerTestCase {

    @Test
    public void testCompilation() {
        QueryProfilesConfig config = new ConfigGetter<>(QueryProfilesConfig.class).getConfig("file:src/test/resources/query-profiles.cfg");
        Instant start = Instant.now();
        QueryProfileCompiler.compile(QueryProfileConfigurer.createFromConfig(config));
        long compilationMillis = start.until(Instant.now(), ChronoUnit.MILLIS);
        System.out.println("Compilation time in seconds: " + compilationMillis / 1000.0);
    }

}
