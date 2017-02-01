require 'fluent/plugin/output'
require 'fluent/clock'

class Fluent::Plugin::SamplingFilterOutput < Fluent::Plugin::Output
  Fluent::Plugin.register_output('sampling_filter', self)

  helpers :event_emitter

  config_param :interval, :integer
  config_param :sample_unit, :enum, list: [:tag, :all], default: :tag
  config_param :remove_prefix, :string, default: nil
  config_param :add_prefix, :string, default: 'sampled'
  config_param :minimum_rate_per_min, :integer, default: nil

  def configure(conf)
    super

    log.warn "sampling_filter output plugin is deprecated. use sampling_filter filter plugin instead with <label> routing."

    if @remove_prefix
      @removed_prefix_string = @remove_prefix + '.'
      @removed_length = @removed_prefix_string.length
    elsif @add_prefix.empty?
      raise Fluent::ConfigError, "either of 'add_prefix' or 'remove_prefix' must be specified"
    end
    @added_prefix_string = nil
    @added_prefix_string = @add_prefix + '.' unless @add_prefix.empty?

    @counts = {}
    @resets = {} if @minimum_rate_per_min
  end

  def emit_sampled(tag, time_record_pairs)
    if @remove_prefix and
        ( (tag.start_with?(@removed_prefix_string) and tag.length > @removed_length) or tag == @remove_prefix)
      tag = tag[@removed_length..-1]
    end
    if tag.length > 0
      tag = @added_prefix_string + tag if @added_prefix_string
    else
      tag = @add_prefix
    end

    time_record_pairs.each {|t,r|
      router.emit(tag, t, r)
    }
  end

  def process(tag, es)
    t = if @sample_unit == :all
          'all'
        else
          tag
        end

    pairs = []

    # Access to @counts SHOULD be protected by mutex, with a heavy penalty.
    # Code below is not thread safe, but @counts (counter for sampling rate) is not
    # so serious value (and probably will not be broken...),
    # then i let here as it is now.
    if @minimum_rate_per_min
      @resets[t] ||= Fluent::Clock.now + (60 - rand(30))
      if Fluent::Clock.now > @resets[t]
        @resets[t] = Fluent::Clock.now + 60
        @counts[t] = 0
      end
      es.each do |time,record|
        c = (@counts[t] = @counts.fetch(t, 0) + 1)
        if c < @minimum_rate_per_min or c % @interval == 0
          pairs.push [time, record]
        end
      end
    else
      es.each do |time,record|
        c = (@counts[t] = @counts.fetch(t, 0) + 1)
        if c % @interval == 0
          pairs.push [time, record]
          # reset only just before @counts[t] is to be bignum from fixnum
          @counts[t] = 0 if c > 0x6fffffff
        end
      end
    end

    emit_sampled(tag, pairs)
  end
end
