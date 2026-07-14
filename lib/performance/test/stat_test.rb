# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require '../stat'

class StatTest < Test::Unit::TestCase
  include Perf

  # Build a Snapshot without going through RealProcFs/system_snapshot, and
  # without triggering host_to_internal metric building (which requires a
  # full field tree with :net, :vm, etc.) -- we only want to exercise the
  # delta logic in isolation here.
  def snapshot(fields)
    Stat::Snapshot.new(fields, :disable_metric_building => true)
  end

  # Regression test for the crash seen in ProgrammaticFeedClientTest::test_throughput:
  # "Class mismatch when subtracting metrics at cpu -> intr -> [301]:
  #  Integer (21) != NilClass (nil)"
  #
  # /proc/stat's 'intr' line length depends on the number of IRQ vectors the
  # kernel currently exposes, which can differ between two snapshots taken
  # seconds apart. This is the direction that actually reproduces the crash:
  # the end snapshot's array is longer than the start snapshot's, so
  # Array#zip pads the missing start-side elements with nil, and entry_delta
  # used to treat Integer vs NilClass as an unexpected type mismatch.
  def test_array_grew_is_skipped_not_raised
    start_snapshot = snapshot(:cpu => { 'intr' => [100, 1, 2] })
    end_snapshot   = snapshot(:cpu => { 'intr' => [140, 5, 9, 21] }) # one more IRQ vector

    result = nil
    assert_nothing_raised do
      result = end_snapshot.subtract(start_snapshot, :disable_metric_building => true)
    end

    # The index only present on the longer side is dropped rather than raising.
    assert_equal([40, 4, 7], result.fields[:cpu]['intr'])
  end

  # The reverse direction: the end snapshot's array is shorter than the start
  # snapshot's. Array#zip's result length always matches the receiver, so
  # this never actually raised even before the fix (the extra start-side
  # element is simply dropped, no nil is produced). Kept as a test to
  # document that this direction remains safe after the fix too.
  def test_array_shrunk_was_already_safe
    start_snapshot = snapshot(:cpu => { 'intr' => [100, 1, 2, 3] })
    end_snapshot   = snapshot(:cpu => { 'intr' => [140, 5, 9] }) # one fewer IRQ vector

    result = nil
    assert_nothing_raised do
      result = end_snapshot.subtract(start_snapshot, :disable_metric_building => true)
    end

    assert_equal([40, 4, 7], result.fields[:cpu]['intr'])
  end

  # A genuine type mismatch (not caused by array-length drift) must still
  # raise loudly -- we don't want to silently hide real bugs.
  def test_genuine_type_mismatch_still_raises
    start_snapshot = snapshot(:cpu => { 'foo' => { :bar => 1 } })
    end_snapshot   = snapshot(:cpu => { 'foo' => 5 })

    error = assert_raise RuntimeError do
      end_snapshot.subtract(start_snapshot, :disable_metric_building => true)
    end
    assert_match(/Class mismatch when subtracting metrics at cpu -> foo/, error.message)
  end

  # Regression test built closer to the real /proc/stat shape produced by
  # Stat::system_snapshot / CpuInfo, rather than only a synthetic minimal
  # Hash. Constructs the 'cpu' sub-hash the way CpuInfo actually would
  # (assoc_array for the 'cpu' aggregate line, plus a raw array for 'intr'),
  # without touching a live /proc filesystem.
  def test_realistic_cpu_fields_with_growing_intr_length
    make_cpu_fields = lambda do |intr_len|
      {
        :cpu => {
          'cpu'  => Stat::assoc_array([:user, :nice, :system, :idle, :iowait, :irq, :softirq],
                                       [100, 0, 50, 900, 0, 0, 0]),
          'intr' => (0...intr_len).to_a,
          'ctxt' => [12345],
          'processes' => [42]
        }
      }
    end

    start_snapshot = snapshot(make_cpu_fields.call(301))
    end_snapshot   = snapshot(make_cpu_fields.call(302)) # one more IRQ vector appeared

    result = nil
    assert_nothing_raised do
      result = end_snapshot.subtract(start_snapshot, :disable_metric_building => true)
    end

    # The 'intr' delta drops the dangling index rather than raising, and the
    # metrics actually consumed downstream (ctxt, processes, the cpu
    # aggregate) are unaffected and still computed correctly.
    assert_equal(301, result.fields[:cpu]['intr'].size)
    assert_equal([0], result.fields[:cpu]['ctxt'])
    assert_equal([0], result.fields[:cpu]['processes'])
    assert_equal(0, result.fields[:cpu]['cpu'][:user])
  end
end
