require 'helper'
require 'fluent/test/driver/output'

class SamplingFilterOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    interval 10
    sample_unit tag
    remove_prefix input
    add_prefix sampled
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::SamplingFilterOutput).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      d = create_driver('')
    }
    d = create_driver %[
      interval 5
    ]

    assert_equal 5, d.instance.interval
    assert_equal :tag, d.instance.sample_unit
    assert_nil d.instance.remove_prefix
    assert_equal 'sampled', d.instance.add_prefix

    d = create_driver %[
      interval 1000
      sample_unit all
      remove_prefix test
      add_prefix output
    ]
    assert_equal 1000, d.instance.interval
    assert_equal :all, d.instance.sample_unit
    assert_equal 'test', d.instance.remove_prefix
    assert_equal 'output', d.instance.add_prefix
  end

  def test_emit
    d1 = create_driver(CONFIG)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d1.run(default_tag: 'input.hoge1') do
      d1.feed(time, {'field1' => 'record1', 'field2' => 1})
      d1.feed(time, {'field1' => 'record2', 'field2' => 2})
      d1.feed(time, {'field1' => 'record3', 'field2' => 3})
      d1.feed(time, {'field1' => 'record4', 'field2' => 4})
      d1.feed(time, {'field1' => 'record5', 'field2' => 5})
      d1.feed(time, {'field1' => 'record6', 'field2' => 6})
      d1.feed(time, {'field1' => 'record7', 'field2' => 7})
      d1.feed(time, {'field1' => 'record8', 'field2' => 8})
      d1.feed(time, {'field1' => 'record9', 'field2' => 9})
      d1.feed(time, {'field1' => 'record10', 'field2' => 10})
      d1.feed(time, {'field1' => 'record11', 'field2' => 11})
      d1.feed(time, {'field1' => 'record12', 'field2' => 12})
    end
    events = d1.events
    assert_equal 1, events.length
    assert_equal 'sampled.hoge1', events[0][0] # tag
    assert_equal 'record10', events[0][2]['field1']
    assert_equal 10, events[0][2]['field2']

    d2 = create_driver(%[
      interval 3
    ])
    time = Time.parse("2012-01-02 13:14:15").to_i
    d2.run(default_tag: 'input.hoge2') do
      d2.feed(time, {'field1' => 'record1', 'field2' => 1})
      d2.feed(time, {'field1' => 'record2', 'field2' => 2})
      d2.feed(time, {'field1' => 'record3', 'field2' => 3})
      d2.feed(time, {'field1' => 'record4', 'field2' => 4})
      d2.feed(time, {'field1' => 'record5', 'field2' => 5})
      d2.feed(time, {'field1' => 'record6', 'field2' => 6})
      d2.feed(time, {'field1' => 'record7', 'field2' => 7})
      d2.feed(time, {'field1' => 'record8', 'field2' => 8})
      d2.feed(time, {'field1' => 'record9', 'field2' => 9})
      d2.feed(time, {'field1' => 'record10', 'field2' => 10})
      d2.feed(time, {'field1' => 'record11', 'field2' => 11})
      d2.feed(time, {'field1' => 'record12', 'field2' => 12})
    end
    events = d2.events
    assert_equal 4, events.length
    assert_equal 'sampled.input.hoge2', events[0][0] # tag

    assert_equal 'record3', events[0][2]['field1']
    assert_equal 'record6', events[1][2]['field1']
    assert_equal 'record9', events[2][2]['field1']
    assert_equal 'record12', events[3][2]['field1']
  end

  def test_minimum_rate
    config = %[
interval 10
sample_unit tag
remove_prefix input
minimum_rate_per_min 100
]
    d = create_driver(config)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run(default_tag: 'input.hoge3') do
      (1..100).each do |t|
        d.feed({'times' => t, 'data' => 'x'})
      end
      (101..130).each do |t|
        d.feed({'times' => t, 'data' => 'y'})
      end
    end
    events = d.events
    assert_equal 103, events.length
    assert_equal 'sampled.hoge3', events[0][0]
    assert_equal ((1..100).map(&:to_i) + [110, 120, 130]), events.map{|t,time,r| r['times']}
    assert_equal (['x']*100 + ['y']*3), events.map{|t,time,r| r['data']}

  end
  def test_minimum_rate_expire
    # hey, this test needs 60 seconds....
    omit("this test needs 60 seconds....") unless ENV["EXECLONGTEST"]

    config = %[
interval 10
sample_unit tag
remove_prefix input
minimum_rate_per_min 10
]
    d = create_driver(config)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run(default_tag: 'input.hoge4') do
      (1..100).each do |t|
        d.feed(time, {'times' => t, 'data' => 'x'})
      end
      sleep 60
      (101..130).each do |t|
        d.feed(time+60, {'times' => t, 'data' => 'y'})
      end
    end
    events = d.events
    # assert_equal (19 + 12), events.length
    assert_equal 'sampled.hoge4', events[0][0]
    assert_equal ((1..10).map(&:to_i)+[20,30,40,50,60,70,80,90,100]+(101..110).map(&:to_i)+[120,130]), events.map{|t,time,r| r['times']}
    assert_equal (['x']*19 + ['y']*12), events.map{|t,time,r| r['data']}
  end

  def test_without_add_prefix_but_remove_prefix
    config = %[
interval 10
add_prefix
remove_prefix input
]
    d = create_driver(config)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run(default_tag: 'input.hoge3') do
      (1..100).each do |t|
        d.feed({'times' => t, 'data' => 'x'})
      end
    end
    events = d.events
    assert_equal 10, events.length
    assert_equal 'hoge3', events[0][0]
  end
end
