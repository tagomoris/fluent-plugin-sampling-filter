# fluent-plugin-sampling-filter

This is a [Fluentd](http://fluentd.org) plugin to sample matching messages to analyse and report messages behavior and emit sampled messages with modified tag.

* sampling rate per tags, message field, or all

## Requirements

| fluent-plugin-sampling-filter | fluentd    | ruby   |
|-------------------------------|------------|--------|
| >= 1.0.0                      | >= v0.14.0 | >= 2.1 |
| <  1.0.0                      | <  v0.14.0 | >= 1.9 |

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
        sample_unit all
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


We can also sample based on a value in the message

    <source>
      @type any_great_input
      @label @mydata
    </source>

    <label @mydata>
      <filter **>
        @type sampling
        interval 10
        # pass 1/10 events per user given events like: { user: { name: "Bob" }, ... }
        sample_unit $.user.name
      </filter>

      <match **>
        @type ...
      </match>
    </label>

`minimum_rate_per_min` option(integer) configures this plugin to pass events with the specified rate even how small is the total number of whole events.

`sample_unit` option(string) configures this plugin to sample data based on tag(default), 'all', or by field value
using the [record accessor syntax](https://docs.fluentd.org/plugin-helper-overview/api-plugin-helper-record_accessor).

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
