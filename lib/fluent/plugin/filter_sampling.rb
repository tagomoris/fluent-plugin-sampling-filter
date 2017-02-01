require 'fluent/plugin/filter'
require 'fluent/clock'

class Fluent::Plugin::SamplingFilter < Fluent::Plugin::Filter
  Fluent::Plugin.register_filter('sampling', self)
  Fluent::Plugin.register_filter('sampling_filter', self)

  config_param :interval, :integer
  config_param :sample_unit, :enum, list: [:tag, :all], default: :tag
  config_param :minimum_rate_per_min, :integer, default: nil

  def configure(conf)
    super

    @counts = {}
    @resets = {} if @minimum_rate_per_min
  end

  # Access to @counts SHOULD be protected by mutex, with a heavy penalty.
  # Code below is not thread safe, but @counts (counter for sampling rate) is not
  # so serious value (and probably will not be broken...),
  # then i let here as it is now.

  def filter(tag, _time, record)
    t = @sample_unit == :all ? 'all' : tag
    if @minimum_rate_per_min
      filter_with_minimum_rate(t, record)
    else
      filter_simple(t, record)
    end
  end

  def filter_simple(t, record)
    c = (@counts[t] = @counts.fetch(t, 0) + 1)
    # reset only just before @counts[t] is to be bignum from fixnum
    @counts[t] = 0 if c > 0x6fffffff
    if c % @interval == 0
      record
    else
      nil
    end
  end

  def filter_with_minimum_rate(t, record)
    @resets[t] ||= Fluent::Clock.now + (60 - rand(30))
    if Fluent::Clock.now > @resets[t]
      @resets[t] = Fluent::Clock.now + 60
      @counts[t] = 0
    end
    c = (@counts[t] = @counts.fetch(t, 0) + 1)
    if c < @minimum_rate_per_min || c % @interval == 0
      record.dup
    else
      nil
    end
  end
end
