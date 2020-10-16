
require 'yaml'
require 'json'

data = YAML.load_file(File.expand_path('../data/variants.yaml', __dir__))
DATA = JSON.parse(data.to_json, object_class: H) # nasty
