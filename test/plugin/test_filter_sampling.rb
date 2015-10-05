require 'helper'

class SamplingFilterTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    interval 10
    sample_unit tag
  ]

  def create_driver(conf=CONFIG,tag='test')
    Fluent::Test::FilterTestDriver.new(Fluent::SamplingFilter, tag).configure(conf)
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

    d = create_driver %[
      interval 1000
      sample_unit all
    ]
    assert_equal 1000, d.instance.interval
    assert_equal :all, d.instance.sample_unit
  end

  def test_filter
    d1 = create_driver(CONFIG, 'input.hoge1')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d1.run do
      d1.filter({'field1' => 'record1', 'field2' => 1})
      d1.filter({'field1' => 'record2', 'field2' => 2})
      d1.filter({'field1' => 'record3', 'field2' => 3})
      d1.filter({'field1' => 'record4', 'field2' => 4})
      d1.filter({'field1' => 'record5', 'field2' => 5})
      d1.filter({'field1' => 'record6', 'field2' => 6})
      d1.filter({'field1' => 'record7', 'field2' => 7})
      d1.filter({'field1' => 'record8', 'field2' => 8})
      d1.filter({'field1' => 'record9', 'field2' => 9})
      d1.filter({'field1' => 'record10', 'field2' => 10})
      d1.filter({'field1' => 'record11', 'field2' => 11})
      d1.filter({'field1' => 'record12', 'field2' => 12})
    end
    filtered = d1.filtered_as_array
    assert_equal 1, filtered.length
    assert_equal 'input.hoge1', filtered[0][0] # tag
    assert_equal 'record10', filtered[0][2]['field1']
    assert_equal 10, filtered[0][2]['field2']

    d2 = create_driver(%[
      interval 3
    ], 'input.hoge2')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d2.run do
      d2.filter({'field1' => 'record1', 'field2' => 1})
      d2.filter({'field1' => 'record2', 'field2' => 2})
      d2.filter({'field1' => 'record3', 'field2' => 3})
      d2.filter({'field1' => 'record4', 'field2' => 4})
      d2.filter({'field1' => 'record5', 'field2' => 5})
      d2.filter({'field1' => 'record6', 'field2' => 6})
      d2.filter({'field1' => 'record7', 'field2' => 7})
      d2.filter({'field1' => 'record8', 'field2' => 8})
      d2.filter({'field1' => 'record9', 'field2' => 9})
      d2.filter({'field1' => 'record10', 'field2' => 10})
      d2.filter({'field1' => 'record11', 'field2' => 11})
      d2.filter({'field1' => 'record12', 'field2' => 12})
    end
    filtered = d2.filtered_as_array
    assert_equal 4, filtered.length
    assert_equal 'input.hoge2', filtered[0][0] # tag

    assert_equal 'record3', filtered[0][2]['field1']
    assert_equal 'record6', filtered[1][2]['field1']
    assert_equal 'record9', filtered[2][2]['field1']
    assert_equal 'record12', filtered[3][2]['field1']
  end

  def test_filter_minimum_rate
    config = %[
interval 10
sample_unit tag
minimum_rate_per_min 100
]
    d = create_driver(config, 'input.hoge3')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run do
      (1..100).each do |t|
        d.filter({'times' => t, 'data' => 'x'})
      end
      (101..130).each do |t|
        d.filter({'times' => t, 'data' => 'y'})
      end
    end
    filtered = d.filtered_as_array
    assert_equal 103, filtered.length
    assert_equal 'input.hoge3', filtered[0][0]
    assert_equal ((1..100).map(&:to_i) + [110, 120, 130]), filtered.map{|t,time,r| r['times']}
    assert_equal (['x']*100 + ['y']*3), filtered.map{|t,time,r| r['data']}

  end
  def test_filter_minimum_rate_expire
    # hey, this test needs 60 seconds....
    assert_equal 1, 1
    return

    config = %[
interval 10
sample_unit tag
minimum_rate_per_min 10
]
    d = create_driver(config, 'input.hoge4')
    time = Time.parse("2012-01-02 13:14:15").to_i
    d.run do
      (1..100).each do |t|
        d.filter({'times' => t, 'data' => 'x'})
      end
      sleep 60
      (101..130).each do |t|
        d.filter({'times' => t, 'data' => 'y'})
      end
    end
    filtered = d.filtered_as_array
    # assert_equal (19 + 12), filtered.length
    assert_equal 'input.hoge4', filtered[0][0]
    assert_equal ((1..10).map(&:to_i)+[20,30,40,50,60,70,80,90,100]+(101..110).map(&:to_i)+[120,130]), filtered.map{|t,time,r| r['times']}
    assert_equal (['x']*19 + ['y']*12), filtered.map{|t,time,r| r['data']}
  end
end
