
require 'ostruct'
require 'hashie/mash'
require 'builder'

module Xmler
  def to_xml(xm)
    each_pair do |name, val|
      case val
      when OpenStruct, H
        xm.tag!(name) { val.to_xml(xm) }
      when Array
        val.each { |v| xm.tag!(name) { v.to_xml(xm) } }
      else
        unless val.nil?
          xm.tag!(name, val)
        end
      end
    end
    xm
  end
end

class H < Hashie::Mash
  include Xmler
end

class OpenStruct
  include Xmler
end

# load fixtures into consts
require File.expand_path('dataloader', __dir__)
