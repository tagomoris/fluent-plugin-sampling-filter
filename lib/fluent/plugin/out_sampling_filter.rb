class Fluent::SamplingFilterOutput < Fluent::Output
  Fluent::Plugin.register_output('sampling_filter', self)

  config_param :interval, :integer
  config_param :sample_unit, :string, :default => 'tag'
  config_param :remove_prefix, :string, :default => nil
  config_param :add_prefix, :string, :default => 'sampled'

  def configure(conf)
    super

    if @remove_prefix
      @removed_prefix_string = @remove_prefix + '.'
      @removed_length = @removed_prefix_string.length
    end
    @added_prefix_string = @add_prefix + '.'

    @sample_unit = case @sample_unit
                   when 'tag'
                     :tag
                   when 'all'
                     :all
                   else
                     raise Fluent::ConfigError, "sample_unit allows only 'tag' or 'all'"
                   end
    @counts = {}
  end

  def emit_sampled(tag, time_record_pairs)
    if @remove_prefix and
        ( (tag.start_with?(@removed_prefix_string) and tag.length > @removed_length) or tag == @remove_prefix)
      tag = tag[@removed_length..-1]
    end
    tag = if tag.length > 0
            @added_prefix_string + tag
          else
            @add_prefix
          end

    time_record_pairs.each {|t,r|
      Fluent::Engine.emit(tag, t, r)
    }
  end

  def emit(tag, es, chain)
    t = if @sample_unit == :all
          'all'
        else
          tag
        end
    # Access to @counts SHOULD be protected by mutex, with a heavy penalty.
    # @counts (counter for sampling rate) is not so serious value (and probably will not be broke...),
    # then i let here as it is now.
    @counts[t] ||= 0
    pairs = []
    es.each {|time,record|
      @counts[t] += 1
      if @counts[t] == @interval
        pairs.push [time, record]
        @counts[t] = 0
      end
    }
    emit_sampled(tag, pairs)

    chain.next
  end
end
