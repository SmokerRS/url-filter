require "uri"
require "json"

struct URLFilter::Rule
  include Enumerable({String, Regex})

  URI_FIELDS = %w{scheme host path query fragment}

  class JSONRegexParser
    def self.from_json(value : JSON::PullParser) : Regex
      Regex.new(value.read_string)
    end
  end

  {% begin %}
    {% for name in URI_FIELDS %}
      getter {{name.id}} : Nil | Regex
      @{{name.id}} = nil
    {% end %}

    def initialize(
      {% for name in URI_FIELDS %}
        @{{name.id}} : Regex,
      {% end %}
    )
    end

    def initialize(rules : Hash(String, Regex))
      rules.each do |field, regex|
        case field
        {% for name in URI_FIELDS %}
          when {{name}} then @{{name.id}} = regex if regex
        {% end %}
        else
          raise ArgumentError.new(%[Invalid field name "#{field}"])
        end
      end
    end

    JSON.mapping(
      {% for name in URI_FIELDS %}
        {{name.id}}: {type: Regex, nilable: true, converter: JSONRegexParser},
      {% end %}
    )

    def_equals_and_hash(
      {% for name in URI_FIELDS %}
        {{name}}, @{{name.id}}.try(&.source),
      {% end %}
    )
  {% end %}

  def each
    {% for name in URI_FIELDS %}
      if (r = @{{name.id}})
        yield({ {{name}}, r })
      end
    {% end %}
  end

  def match?(uri : URI) : Bool
    {% begin %}
    (
      {% for name in URI_FIELDS %}
        (
          (r = @{{name.id}}) \
          && (u = uri.{{name.id}}) \
          && r.match(u) \
          || r.nil?
        ) &&
      {% end %}
      true
    ).as(Bool)
    {% end %}
  end
end
