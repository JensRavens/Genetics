require "genetics/version"
require "clamp"
require "json"
require "erb"
require "active_support/all"

module Genetics
  class Attribute
    attr_reader :id

    def initialize(id)
      @id = id
    end

    def optional?
      id.end_with? "?"
    end

    def int?
      id.start_with? "int"
    end

    def string?
      id.start_with? "string"
    end

    def date?
      id.start_with? "date"
    end

    def array?
      id.match(/\A\[(.+)\]\z/)
    end

    def type
      return :int if int?
      return :string if string?
      return :date if date?
      return :array if array?
      return :string
      # fail "unknown attribute type"
    end

    def to_s
      id
    end
  end

  class DNA
    attr_reader :json
    attr_reader :models

    def initialize(text)
      @json = JSON.parse(text)
      @models = json['models'].map { |name, content| Model.new(name, content) }
    end

    def to_s
      models.map(&:to_s).join("\n\n")
    end
  end

  class Renderer
    attr_reader :template
    attr_reader :template_path
    attr_reader :dna
    attr_reader :erb

    def initialize(template_path, dna)
      @template_path = template
      @template = File.read template_path
      @dna = dna
      @erb = ERB.new(template, nil, '-')
    end

    def build
      dna.models.each do |model|
        content = render(model)
        File.write("results/#{model.name}.swift", content)
      end
    end

    def render(model)
      erb.result(model.context).strip
    end
  end

  class Model
    attr_reader :id
    attr_reader :attributes

    def initialize(id, content)
      @id = id
      @attributes = {}
      content.each do |key, value|
        @attributes[key] = Attribute.new(value)
      end
    end

    def name
      id.classify
    end

    def to_s
      ["#{id}:", attributes.map { |k, v| "\t #{k}: #{v}" }].flatten.join("\n")
    end

    def context
      binding
    end
  end
end

Clamp do
  parameter "File", "The json file containing your api description.", attribute_name: :json_file

  def execute
    dna = Genetics::DNA.new(File.read(json_file))
    renderer = Genetics::Renderer.new("template.swift.erb", dna)
    renderer.build
  end
end
