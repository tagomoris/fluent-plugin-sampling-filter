# fluent-plugin-sampling-filter

This is a [Fluentd](http://fluentd.org) plugin to sample matching messages to analyse and report messages behavior and emit sampled messages with modified tag.

* sampling rate per tags, or for all

## Configuration

### SamplingFilter

This filter passes a specified part of whole events to following filter/output plugins:

    <source>
      @type any_great_input
      @label @mydata
    </source>
    
    <label @mydata>
      <filter **>
        @type sampling
        interval 10    # pass 1/10 events to following plugins
      </filter>
      
      <match **>
        @type ...
      </match>
    </label>

Sampling is done for all events, but we can do it per matched tags:

    <source>
      @type any_great_input
      @label @mydata
    </source>
    
    <label @mydata>
      <filter **>
        @type sampling
        interval 10
        sample_unit tag # 1/10 events for each tags
      </filter>
      
      <match **>
        @type ...
      </match>
    </label>

`minimum_rate_per_min` option(integer) configures this plugin to pass events with the specified rate even how small is the total number of whole events.

### SamplingFilterOutput

**NOTE: This plugin is deprecated. Use filter plugin instead.**

Pickup 1/10 messages about each tags(default: `sample_unit tag`), and add tag prefix `sampled`.

    <match **>
      @type sampling_filter
      interval 10
      add_prefix sampled
    </match>
    
    <match sampled.**>
      # output configurations where to send sampled messages
    </match>

Pickup 1/100 messages of all matched messages, and modify tags from `input.**` to `output.**`

    <match input.**>
      @type sampling_filter
      interval 100
      sample_unit all
      remove_prefix input
      add_prefix output
    </match>
    
    <match sampled.**>
      # output configurations where to send sampled messages
    </match>

## TODO

* patches welcome!

## Copyright

* Copyright
  * Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
* License
  * Apache License, Version 2.0
