# fluent-plugin-sampling-filter

## Component

### SamplingFilterOutput

Do sampling from matching messages to analyse and report messages behavior, and emit sampled messages with modified tag.

* sampling rate per tags, or for all
* remove_prefix of tags for input messages, and add_prefix of tags for output(sampled) messages

## Configuration

### SamplingFilterOutput

Pickup 1/10 messages about each tags(default: `sample_unit tag`), and add tag prefix `sampled`.

    <match **>
      type sampling_filter
      interval 10
      add_prefix sampled
    </match>
    
    <match sampled.**>
      # output configurations where to send sampled messages
    </match>

Pickup 1/100 messages of all matched messages, and modify tags from `input.**` to `output.**`

    <match input.**>
      type sampling_filter
      interval 100
      sample_unit all
      remove_prefix input
      add_prefix output
    </match>
    
    <match sampled.**>
      # output configurations where to send sampled messages
    </match>

## TODO

* consider what to do next
* patches welcome!

## Copyright

* Copyright
  * Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
* License
  * Apache License, Version 2.0
