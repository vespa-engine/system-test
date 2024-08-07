// Copyright Vespa.ai. All rights reserved.
package util;

import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Random;
import java.util.StringJoiner;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.BiFunction;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.stream.Stream;

import static util.DataGenerator.Argument.cutoff;
import static util.DataGenerator.Argument.count;
import static util.DataGenerator.Argument.prefix;
import static util.DataGenerator.Argument.suffix;
import static util.DataGenerator.Argument.template;
import static java.lang.Math.floorMod;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.Arrays.binarySearch;
import static java.util.Comparator.comparingLong;
import static java.util.function.Function.identity;
import static java.util.function.Predicate.not;
import static java.util.stream.Collectors.counting;
import static java.util.stream.Collectors.groupingBy;

/**
 * @author jonmv
 */
public class DataGenerator {

    public static void main(String[] args) {
        try {
            Command.valueOf(args[0]).run(args);
        }
        catch (RuntimeException e) {
            e.printStackTrace();
            usage();
            System.exit(1);
        }
    }

    static void usage() {
        System.err.println("\nUsage: java DataGenerator.java <command> [option-name option-value]...\n");

        System.err.println("Examples: echo \"some words.com with#gurba+gurba\" | java DataGenerator.java digest cutoff 1 > words.txt\n");
        System.err.println("          cat words.txt | java DataGenerator.java feed count 3 template '{ \"id\": \"id:ns:type::$seq()\", \"text\": \"$words(3)\" }'\n");
        System.err.println("          echo \"1 rare 4 common\" | java DataGenerator.java query template 'sddocname:type foo:$words()'\n");
        System.err.println("          : | java DataGenerator.java url template 'my-doc-$seq()' prefix '/document/v1/ns/type/docid/' suffix '?fields=%5Bid%5D'\n");

        System.err.println("List of commands:\n");
        for (Command command : Command.values()) {
            System.err.printf("%12s: %s\n", command.name(), command.description);
            for (Argument argument : command.arguments)
                System.err.printf("%14s%s: %s, %s\n", "", argument.name(), argument.description, argument.fallback != null ? "default '" + argument.fallback + "'": "required");
            System.err.println();
        }

        System.err.println("List of patterns (default count is 1, i.e., $words() and $words(1) are the same):\n");
        for (Pattern pattern : Pattern.values())
            System.err.printf("%12s: %s\n", pattern.name(), pattern.description);
    }

    static void countWords(EnumMap<Argument, String> arguments) {
        Map<String, Long> frequencies = new BufferedReader(new InputStreamReader(System.in, UTF_8))
                .lines().parallel()
                .flatMap(line -> Stream.of(line.split("[\\W&&[^-.']]")) // Split on non-word-chars except -.'
                                       .map(word -> {
                                           int s = 0, e = word.length();
                                           while (s < e && isIntraWordPunctuation(word.codePointAt(s))) s++;
                                           while (s < e && isIntraWordPunctuation(word.codePointAt(e - 1))) e--;
                                           return word.substring(s, e).toLowerCase(Locale.ROOT);
                                       })
                                       .filter(not(String::isBlank)))
                .collect(groupingBy(identity(), counting()));

        int lower = Integer.parseInt(arguments.get(cutoff));
        frequencies.entrySet().stream()
                   .filter(wordCount -> wordCount.getValue() > lower)
                   .sorted(comparingLong(wordCount -> -wordCount.getValue()))
                   .forEach(wordCount -> System.out.println(wordCount.getValue() + " " + wordCount.getKey()));
    }

    static boolean isIntraWordPunctuation(int c) {
        return c == '\'' || c == '-' || c == '.';
    }

    static void generateURLs(EnumMap<Argument, String> arguments, String key, String suffix) {
        int total = Integer.parseInt(arguments.get(count));
        PrintStream out = new PrintStream(new BufferedOutputStream(System.out));
        Supplier<String> queries = parseTemplate(arguments.get(template), Generator.readFromSystemIn(total));
        String base = arguments.get(prefix);
        String url = key.isEmpty() || base.endsWith("?") || base.endsWith("&") ? base : base + (base.contains("?") ? "&" : "?");
        Supplier<String> urls = () -> url + key + URLEncoder.encode(queries.get(), UTF_8) + suffix;
        for (int i = 0; i < total; i++)
            out.println(urls.get());
        out.flush();
    }

    static void generateFeed(EnumMap<Argument, String> arguments) {
        int total = Integer.parseInt(arguments.get(count));
        PrintStream out = new PrintStream(new BufferedOutputStream(System.out));
        Supplier<String> documents = parseTemplate(arguments.get(template), Generator.readFromSystemIn(total));
        out.println("[");
        for (int i = Integer.parseInt(arguments.get(count)); i > 0; ) {
            out.print(documents.get());
            out.println(--i > 0 ? "," : "");
        }
        out.println("]");
        out.flush();
    }

    static EnumMap<Argument, String> parseArguments(String[] args) {
        EnumMap<Argument, String> arguments = new EnumMap<>(Argument.class);
        for (int i = 1; i < args.length; )
            if (arguments.put(Argument.valueOf(args[i++]), args[i++]) != null)
                throw new IllegalArgumentException("Duplicate argument " + args[i - 2]);

        return arguments;
    }

    static Supplier<String> parseTemplate(String raw, Generator generator) {
        List<String> context = new ArrayList<>();
        List<Supplier<String>> patterns = new ArrayList<>();
        for (int e = -1; e < raw.length(); ) {
            context.add(raw.substring(++e, e = (e = raw.indexOf('$', e)) == -1 ? raw.length() : e));
            if (e < raw.length())
                patterns.add(Pattern.valueOf(raw.substring(++e, e = raw.indexOf('(', e)))
                                    .sequence(raw.substring(++e, e = raw.indexOf(')', e)), generator));
            else
                patterns.add(() -> "");
        }
        return () -> {
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < context.size(); i++)
                builder.append(context.get(i)).append(patterns.get(i).get());
            return builder.toString();
        };
    }

    enum Command {

        digest("extract the words from stdin and count their occurrences", DataGenerator::countWords, cutoff),
        query("generate simple queries from the given template", arguments -> generateURLs(arguments, "query=", ""), count, template, prefix),
        yql("generate yql queries from the given template", arguments -> generateURLs(arguments, "yql=", ""), count, template, prefix),
        url("generate generic URLs from the given template", arguments -> generateURLs(arguments, "", arguments.get(suffix)), count, template, prefix, suffix),
        feed("generate documents from the given template", DataGenerator::generateFeed, count, template);

        final String description;
        final Consumer<EnumMap<Argument, String>> program;
        final List<Argument> arguments;

        Command(String description, Consumer<EnumMap<Argument, String>> program, Argument... arguments) {
            this.description = description;
            this.program = program;
            this.arguments = List.of(arguments);
        }

        void run(String[] args) {
            EnumMap<Argument, String> arguments = parseArguments(args);
            for (Argument name : arguments.keySet())
                if ( ! this.arguments.contains(name))
                    throw new IllegalArgumentException("illegal argument " + name + " for command " + this);

            for (Argument argument : this.arguments)
                if ( ! arguments.containsKey(argument))
                    if (argument.fallback == null)
                        throw new IllegalArgumentException("missing required argument " + argument.name() + " for command " + this);
                    else
                        arguments.put(argument, argument.fallback);

            program.accept(arguments);
        }

    }

    enum Argument {

        cutoff("drop all words with frequency no more than this from the tally", "0"),
        count("number of items to generate; these are separated by newlines", "10"),
        template("template to use for queries or feed operations; will be encoded in URLs", null),
        prefix("URL prefix (path and query); will not be URL-encoded", "/search/"),
        suffix("URL suffix (typically query); will not be URL-encoded", "");

        final String description;
        final String fallback;

        Argument(String description, String fallback) {
            this.description = description;
            this.fallback = fallback;
        }

    }

    enum Pattern {

        seq("A sequence which starts at an optional offset, and increments by 1 for each item, e.g., $seq(32)", (arguments, generator) -> {
            if (arguments.length > 1) throw new IllegalArgumentException("seq accepts 0 or 1 arguments");
            AtomicLong counter = new AtomicLong(arguments.length == 0 ? 0 : Long.parseLong(arguments[0]));
            return () -> Long.toString(counter.getAndIncrement());
        }),

        rseq("A permutation of the numbers [0, N) where N is the number of items to generate, e.g., $rseq()", (arguments, generator) -> {
            if (arguments.length > 0) throw new IllegalArgumentException("rseq accepts no arguments");
            int[] numbers = new int[generator.total];
            for (int i = 0; i < numbers.length; ) numbers[i] = i++;
            AtomicInteger end = new AtomicInteger(numbers.length);
            return () -> {
                int i = generator.random.nextInt(end.get());
                int n = numbers[i];
                numbers[i] = numbers[end.decrementAndGet()];
                return Integer.toString(n);
            };
        }),

        include("The second argument with probability equal to the first; or nothing, e.g., $include(0.5, \"fifty-fifty\")", (arguments, generator) -> {
            if (arguments.length != 2) throw new IllegalArgumentException("include requires exactly 2 arguments");
            double probability = Double.parseDouble(arguments[0]);
            String value = arguments[1];
            return () -> generator.random.nextDouble() < probability ? value : "";
        }),

        pick("N comma-separated, unique picks from the given candidates, e.g., $words(2, \"cat\", \"bird\", \"fish\")", (arguments, generator) -> {
            if (arguments.length < 1) throw new IllegalArgumentException("pick requires a number of words to pick");
            int words = Integer.parseInt(arguments[0]);
            if (arguments.length < 1 + words) throw new IllegalArgumentException("cannot supply fewer words than number to pick");
            return () -> {
                StringJoiner joiner = new StringJoiner(",");
                for (int i = arguments.length; i > arguments.length - words; ) {
                    int pick = generator.random.nextInt(--i) + 1;
                    String picked = arguments[pick];
                    arguments[pick] = arguments[i];
                    arguments[i] = picked;
                    joiner.add(picked);
                }
                return joiner.toString();
            };
        }),

        words("N randomly chosen words from the global tally, e.g., $words(5)", (arguments, generator) -> {

            if (arguments.length > 1) throw new IllegalArgumentException("words accepts 0 or 1 arguments");
            int words = arguments.length == 0 ? 1 : Integer.parseInt(arguments[0]);
            return () -> {
                StringJoiner joiner = new StringJoiner(" ");
                for (int i = 0; i < words; i++)
                    joiner.add(generator.nextWord());
                return joiner.toString();
            };
        }),

        chars("Randomly chosen words truncated after N characters, e.g., $chars(32)", (arguments, generator) -> {
            if (arguments.length > 1) throw new IllegalArgumentException("chars accepts 0 or 1 arguments");
            int chars = arguments.length == 0 ? 1 : Integer.parseInt(arguments[0]);
            return () -> generator.nextChars(chars);
        }),

        ints("N random, comma-separated integers less than an optional bound, e.g., $ints(1, 100)", (arguments, generator) -> {
            if (arguments.length > 2) throw new IllegalArgumentException("ints accepts 0, 1 or 2 arguments");
            int numbers = arguments.length == 0 ? 1 : Integer.parseInt(arguments[0]);
            long bound = arguments.length <= 1 ? 0 : Long.parseLong(arguments[1]);
            return () -> {
                StringJoiner joiner = new StringJoiner(",");
                for (int i = 0; i < numbers; i++)
                    joiner.add(Long.toString(bound > 0 ? generator.nextLong(bound) : generator.random.nextLong()));
                return joiner.toString();
            };
        }),

        floats("N random, comma-separated (double) floats, in the range [0, 1), e.g., $floats(2)", (arguments, generator) -> {
            if (arguments.length > 1) throw new IllegalArgumentException("floats accepts 0 or 1 arguments");
            int floats = arguments.length == 0 ? 1 : Integer.parseInt(arguments[0]);
            return () -> {
                StringJoiner joiner = new StringJoiner(",");
                for (int i = 0; i < floats; i++)
                    joiner.add(Double.toString(generator.random.nextDouble()));
                return joiner.toString();
            };
        }),

        filter("Includes each value, comma-separated, with probability value divided by the first argument; e.g., $filter(100, 10, 50, 90)", (arguments, generator) -> {
            if (arguments.length < 2) throw new IllegalArgumentException("filter requires at least two arguments");
            long[] numbers = new long[arguments.length];
            long divisor = Long.parseLong(arguments[0]);
            if (divisor <= 0) throw new IllegalArgumentException("divisor must be posiive");
            for (int i = 1; i < arguments.length; i++) {
                numbers[i] = Long.parseLong(arguments[i]);
                if (numbers[i] <= 0 || numbers[i] > divisor) throw new IllegalArgumentException("filter term must be in (0, divisor], but was " + numbers[i]);
            }

            return () -> {
                StringJoiner joiner = new StringJoiner(",");
                for (int i = 1; i < numbers.length; i++)
                    if (generator.nextLong(divisor) < numbers[i])
                        joiner.add(Long.toString(numbers[i]));
                return joiner.toString();
            };
        });

        final String description;
        final BiFunction<String[], Generator, Supplier<String>> factory;

        Pattern(String description, BiFunction<String[], Generator, Supplier<String>> factory) {
            this.description = description;
            this.factory = factory;
        }

        Supplier<String> sequence(String arguments, Generator generator) {
            return factory.apply(Stream.of(arguments.split("\\s*,\\s*")).filter(not(String::isBlank)).toArray(String[]::new), generator);
        }

    }

    static class Generator {

        final int total;
        final Random random;
        final long[] counts;
        final String[] words;
        final long count;

        Generator(int total, Random random, long[] counts, String[] words) {
            this.total = total;
            this.random = random;
            this.words = words;
            long count = 0;
            int i = 0;
            this.counts = new long[counts.length];
            for (long c : counts) this.counts[i++] = count += c;
            this.count = count;
        }

        static Generator readFromSystemIn(int total) {
            List<Long> counts = new ArrayList<>();
            List<String> words = new ArrayList<>();
            new BufferedReader(new InputStreamReader(System.in, UTF_8)).lines().forEach(line -> {
                if (line.isBlank()) return;
                String[] parts = line.split("\\s");
                for (int i = 0; i < parts.length; ) {
                    long count = Long.parseLong(parts[i++]);
                    if (count <= 0) throw new IllegalArgumentException("counts must be positive");
                    counts.add(count);
                    words.add(parts[i++]);
                }
            });
            return new Generator(total,
                                 new Random(-1),
                                 counts.stream().mapToLong(Long::longValue).toArray(),
                                 words.toArray(String[]::new));
        }

        String nextChars(int chars) {
            StringBuilder builder = new StringBuilder();
            while (builder.length() < chars) builder.append(nextWord()).append(" ");
            return builder.substring(0, chars);
        }

        String nextWord() {
            if (words.length == 0) throw new IllegalArgumentException("no word counts given in stdin");
            int i = binarySearch(counts, nextLong(count));
            if (i < 0) i = ~i;
            return words[i];
        }

        long nextLong(long bound) {
            if (bound <= 0) throw new IllegalArgumentException("bound must be positive");
            if (bound <= Integer.MAX_VALUE) return random.nextInt((int) bound);
            long l, c; // Avoid skew due to bound not dividing 2^64, by discarding raw values close to overflow.
            do { l = random.nextLong(); } while ((c = (l - floorMod(l, count))) > c + count);
            return floorMod(l, count);
        }

    }

}
