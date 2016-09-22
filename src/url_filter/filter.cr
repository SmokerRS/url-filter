struct URLFilter::Filter
  @rules = [] of Rule

  def initialize(@rules : Array(Rule))
  end

  delegate size, to: @rules

  def <<(rule : Rule)
    @rules << rule
  end

  def optimize!
    @rules.reject{|rule| rule.size <= 0 }

    common_rules = {} of String => Array(Regex)
    @rules.dup.each do |rule|
      if rule.size == 1
        field, regex = rule.first
        if regex
          common_rules[field] = [] of Regex unless common_rules[field]?
          common_rules[field] << regex
        end
        @rules.delete(rule)
      end
    end

    common_rules.each do |field, regexs|
      @rules << Rule.new({ field => Regex.union(regexs) })
    end

    self
  end

  def match?(uri : URI) : Bool
    @rules.each do |rule|
      return true if rule.match?(uri)
    end
    false
  end

  def match?(uri : String) : Bool
    match?(URI.parse(uri))
  end
end
