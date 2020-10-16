#!/usr/bin/ruby

$: << __dir__

require 'optionparser'
require 'optparse/date'
require 'factory_bot'

require 'faker'
require 'zlib'
require 'pp'

require 'spec/utils'

def parse_options
	options = {
      count: 1,
      records: 3,
  }

	OptionParser.new do |opts|
    opts.banner = "Fake DMARC reports generator.\n\nUsage: #{$0} options\n\n"

		opts.on('--backward DAYS', Integer, 'span that many days back')
		opts.on('--start DATE', Date, 'start date')
		opts.on('--end DATE', Date, 'end date')
		opts.on('--records NUM', Integer, 'number of records in the report')
    opts.on('--count NUM', Integer, 'number of reports')

    opts.on('--outdir DIR', 'write compressed report into this dir')
    opts.on('--[no-]random-domain', 'use random policy domain')

		opts.on("--help") do
			puts opts
			exit 0
    end
	end.parse!(into: options)

  unless options[:backward] or (options[:start] and options[:end])
    raise ArgumentError, 'wrong args supplied'
  end

	options
end

def init
  FactoryBot.find_definitions

  %i[
    User Feedback ReportMetadata PolicyPublished Record Row
    AuthResults SpfAuthResults DkimAuthResults
  ].each do |sym|
    self.class.const_set(sym, Class.new(OpenStruct))
  end

  parse_options
end

module Runtime
  module_function
  def generate(options)
    report = FactoryBot.build(:feedback, record_count: options[:records], time: options.slice(:backward, :start, :end), random_domain: options[:'random-domain'])

    builder = Builder::XmlMarkup.new(indent: 4)
    builder.instruct!

    xmlreport = builder.feedback { report.to_xml(builder) }

    if (dir = options[:outdir])
      filename = "static-receiver.local!#{report.policy_published.domain}!#{report.report_metadata.date_range.begin}!" +
          "#{report.report_metadata.date_range.end}!#{report.report_metadata.report_id}.xml.gz"

      raise "Can't write to #{dir}" unless File.writable?(dir)

      Zlib::GzipWriter.open(File.join(dir, filename)) do |gz|
        gz << xmlreport
      end
    else
      print xmlreport
    end
  end
end

def main
  options = init

  options.delete(:count).times do
    Runtime.generate(options)
  end
end

main