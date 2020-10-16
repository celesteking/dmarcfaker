## DMARC fake reports generator

Hey, psst. Want some fake DMARC reports?

*We've got them!*

### Installation

Get some ruby, then `bundle install`.

### Usage

```bash
# will output XML file to terminal spanning last day
./runme.rb --backward 1 --records 3

# will write 2 compressed XML files to ./output/ dir
./runme.rb --backward 1 --records 3 --count 2 --out ./output/

./runme.rb --help
```

Take a look at `data/variants.yaml` where you can define a list of policy domains that will be cycled through during report generation.

### License

Copyright 2020 Yuri Arabadji. Licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).