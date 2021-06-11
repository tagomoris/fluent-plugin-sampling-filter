require 'helper'
require 'fluent/test/driver/filter'

class SamplingFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    interval 10
    sample_unit tag
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::SamplingFilter).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      create_driver('')
    }
    d = create_driver %[
      interval 5
    ]

    assert_equal 5, d.instance.interval
    assert_equal 'tag', d.instance.sample_unit

    d = create_driver %[
      interval 1000
      sample_unit all
    ]
    assert_equal 1000, d.instance.interval
    assert_equal 'all', d.instance.sample_unit

    d = create_driver %[
      interval 1000
      sample_unit $fake
    ]
    assert_equal 1000, d.instance.interval
    assert_equal "$fake", d.instance.sample_unit
  end

  def test_filter
    d1 = create_driver(CONFIG)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d1.run(default_tag: 'input.hoge1') do
      d1.feed({'field1' => 'record1', 'field2' => 1})
      d1.feed({'field1' => 'record2', 'field2' => 2})
      d1.feed({'field1' => 'record3', 'field2' => 3})
      d1.feed({'field1' => 'record4', 'field2' => 4})
      d1.feed({'field1' => 'record5', 'field2' => 5})
      d1.feed({'field1' => 'record6', 'field2' => 6})
      d1.feed({'field1' => 'record7', 'field2' => 7})
      d1.feed({'field1' => 'record8', 'field2' => 8})
      d1.feed({'field1' => 'record9', 'field2' => 9})
      d1.feed({'field1' => 'record10', 'field2' => 10})
      d1.feed({'field1' => 'record11', 'field2' => 11})
      d1.feed({'field1' => 'record12', 'field2' => 12})
    end
    filtered = d1.filtered
    assert_equal 1, filtered.length
    assert_equal 'record10', filtered[0][1]['field1']
    assert_equal 10, filtered[0][1]['field2']

    d2 = create_driver(%[
      interval 3
    ])
    time = Time.parse("2012-01-02 13:14:15").to_i
    d2.run(default_tag: 'input.hoge2') do
      d2.feed({'field1' => 'record1', 'field2' => 1})
      d2.feed({'field1' => 'record2', 'field2' => 2})
      d2.feed({'field1' => 'record3', 'field2' => 3})
      d2.feed({'field1' => 'record4', 'field2' => 4})
      d2.feed({'field1' => 'record5', 'field2' => 5})
      d2.feed({'field1' => 'record6', 'field2' => 6})
      d2.feed({'field1' => 'record7', 'field2' => 7})
      d2.feed({'field1' => 'record8', 'field2' => 8})
      d2.feed({'field1' => 'record9', 'field2' => 9})
      d2.feed({'field1' => 'record10', 'field2' => 10})
      d2.feed({'field1' => 'record11', 'field2' => 11})
      d2.feed({'field1' => 'record12', 'field2' => 12})
    end
    filtered = d2.filtered
    assert_equal 4, filtered.length

    assert_equal 'record3', filtered[0][1]['field1']
    assert_equal 'record6', filtered[1][1]['field1']
    assert_equal 'record9', filtered[2][1]['field1']
    assert_equal 'record12', filtered[3][1]['field1']
  end

  def test_filter_minimum_rate
    config = %[
interval 10
sample_unit tag
minimum_rate_per_min 100
]
    d = create_driver(config)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run(default_tag: 'input.hoge3') do
      (1..100).each do |t|
        d.feed(time, {'times' => t, 'data' => 'x'})
      end
      (101..130).each do |t|
        d.feed(time, {'times' => t, 'data' => 'y'})
      end
    end
    filtered = d.filtered
    assert_equal 103, filtered.length
    assert_equal ((1..100).map(&:to_i) + [110, 120, 130]), filtered.map{|_time,r| r['times']}
    assert_equal (['x']*100 + ['y']*3), filtered.map{|_time,r| r['data']}
  end

  def test_filter_minimum_rate_expire
    config = %[
interval 10
sample_unit tag
minimum_rate_per_min 10
]
    d = create_driver(config)
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run(default_tag: 'input.hoge4') do
      (1..30).each do |t|
        d.feed(time, {'times' => t, 'data' => 'x'})
      end
    end
    filtered = d.filtered
    assert_equal 12, filtered.length
    assert_equal ((1..10).map(&:to_i)+[20,30]), filtered.map{|_time,r| r['times']}
    assert_equal (['x']*12), filtered.map{|_time,r| r['data']}
  end

  def test_filer_with_record_accessor
    d2 = create_driver(%[
      interval 3
      sample_unit field3
    ])
    time = Time.parse("2012-01-02 13:14:15").to_i
    d2.run(default_tag: 'input.hoge2') do
      (1..12).each do |i|
        [1,2].each do |sample_vaule|
          d2.feed({'field1' => "record#{i}", 'field2' => i, 'field3' => sample_vaule})
        end
      end
    end
    filtered = d2.filtered
    assert_equal 8, filtered.length

    assert_equal 'record3', filtered[0][1]['field1']
    assert_equal 1, filtered[0][1]['field3']
    assert_equal 'record3', filtered[1][1]['field1']
    assert_equal 2, filtered[1][1]['field3']
    assert_equal 'record6', filtered[2][1]['field1']
    assert_equal 1, filtered[2][1]['field3']
    assert_equal 'record6', filtered[3][1]['field1']
    assert_equal 2, filtered[3][1]['field3']
    assert_equal 'record9', filtered[4][1]['field1']
    assert_equal 1, filtered[4][1]['field3']
    assert_equal 'record9', filtered[5][1]['field1']
    assert_equal 2, filtered[5][1]['field3']
    assert_equal 'record12', filtered[6][1]['field1']
    assert_equal 1, filtered[6][1]['field3']
    assert_equal 'record12', filtered[7][1]['field1']
    assert_equal 2, filtered[7][1]['field3']
  end
end
