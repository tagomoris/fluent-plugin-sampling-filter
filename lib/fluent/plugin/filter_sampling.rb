class Fluent::SamplingFilter < Fluent::Filter
  Fluent::Plugin.register_filter('sampling_filter', self)

  config_param :interval, :integer
  config_param :sample_unit, :string, default: 'tag'
  config_param :minimum_rate_per_min, :integer, default: nil

  def configure(conf)
    super

    @sample_unit = case @sample_unit
                   when 'tag'
                     :tag
                   when 'all'
                     :all
                   else
                     raise Fluent::ConfigError, "sample_unit allows only 'tag' or 'all'"
                   end
    @counts = {}
    @resets = {} if @minimum_rate_per_min
  end

  def filter_stream(tag, es)
    t = if @sample_unit == :all
          'all'
        else
          tag
        end

    new_es = Fluent::MultiEventStream.new

    # Access to @counts SHOULD be protected by mutex, with a heavy penalty.
    # Code below is not thread safe, but @counts (counter for sampling rate) is not
    # so serious value (and probably will not be broken...),
    # then i let here as it is now.
    if @minimum_rate_per_min
      unless @resets[t]
        @resets[t] = Fluent::Engine.now + (60 - rand(30))
      end
      if Fluent::Engine.now > @resets[t]
        @resets[t] = Fluent::Engine.now + 60
        @counts[t] = 0
      end
      es.each do |time,record|
        c = (@counts[t] = @counts.fetch(t, 0) + 1)
        if c < @minimum_rate_per_min or c % @interval == 0
          new_es.add(time, record.dup)
        end
      end
    else
      es.each do |time,record|
        c = (@counts[t] = @counts.fetch(t, 0) + 1)
        if c % @interval == 0
          new_es.add(time, record.dup)
          # reset only just before @counts[t] is to be bignum from fixnum
          @counts[t] = 0 if c > 0x6fffffff
        end
      end
    end
    new_es
  end
end
