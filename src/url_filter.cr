require "./url_filter/*"
require "option_parser"

module URLFilter
  def self.warning(msg : String)
    STDERR.puts "Warning: #{msg}"
  end

  def self.error(msg : String)
    abort "ERROR: #{msg}"
  end

  struct Options
    USAGE = "usage: #{$0} [options] [-b blacklist_file] [-w whitelist_file]"\
      "< url_file"

    property input : String
    property output : String
    property blacklist : String | Nil
    property whitelist : String | Nil
    property count : Bool

    @input = "-"
    @output = "-"
    @blacklist = nil
    @whitelist = nil
    @count = false

    def self.parse
      options = Options.new

      parser = OptionParser.new
      parser.banner = USAGE

      parser.on("-i FILE", "--input=FILE", "Read URLs' list from a file") do |f|
        options.input = f unless f.empty?
      end

      parser.on("-o FILE", "--output=FILE", "Write filtred URLs to a file")\
      do |f|
        options.output = f unless f.empty?
      end

      parser.on("-b FILE", "--blacklist=FILE", "Use a blacklist") do |f|
        options.blacklist = f unless f.empty?
      end

      parser.on("-w FILE", "--whitelist=FILE", "Use a whitelist") do |f|
        options.whitelist = f unless f.empty?
      end

      parser.on("-c", "--count", "Count filtred URLs instead of printing them")\
      do
        options.count = true
      end

      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end

      extra_args = parser.parse!

      return options, extra_args

    rescue e : OptionParser::InvalidOption
      URLFilter.error(e.message || "Invalid option")
    end
  end

  def self.load_filter(filename : String) : URLFilter::Filter
    if File.readable?(filename)
      begin
        content = File.read(filename)
        rules = Array(URLFilter::Rule).from_json(content)
        URLFilter::Filter.new(rules)
      rescue e: Exception
        error("cannot load the filter file #{filename.inspect} "\
          "(#{e.class.name}: #{e.message})")
      end
    else
      error("cannot read #{filename.inspect}")
    end
  end

  def self.load_inout(filename, mode, default)
    if filename
      if filename == "-"
        input = default
      else
        error("cannot open #{filename.inspect}") unless File.readable?(filename)
        input = File.open(filename, mode)
      end
    else
      input = default
    end
  end

  def self.run
    input = output = blacklist = whitelist = nil

    # parse options
    options, extra_args = Options.parse

    # FIXME: type inference issue, the first try() should be removed
    warning("extra argument(s) #{extra_args.try(&.join(", "))}") \
      if extra_args.try(&.any?)

    # load input and output
    input = load_inout(options.input, "r", STDIN)
    output = load_inout(options.output, "w", STDOUT)

    # load filter lists
    options.blacklist.try{|f| blacklist = load_filter(f) }
    options.whitelist.try{|f| whitelist = load_filter(f) }
    error("no filter was defined") unless blacklist || whitelist
    STDERR.puts "loaded "\
      "#{blacklist ? "blacklist: #{blacklist.size} rules, " : ""}"\
      "#{whitelist ? "whitelist: #{whitelist.size} rules" : ""}"

    # optimize filter lists
    blacklist.try(&.optimize!)
    whitelist.try(&.optimize!)
    STDERR.puts "optimized "\
      "#{blacklist ? "blacklist: #{blacklist.size} rules, " : ""}"\
      "#{whitelist ? "whitelist: #{whitelist.size} rules" : ""}"

    # start filtering
    total = count = 0
    start_time = Time.now
    input.each_line do |url|
      if (whitelist && whitelist.match?(url) || whitelist.nil?) \
      && (blacklist && !blacklist.match?(url) || blacklist.nil?)
        if options.count
          count += 1
        else
          output.puts url
        end
      end
      total += 1
    end
    output.puts count.to_s if options.count
    output.flush unless output.sync?

    STDERR.puts "done filtering #{total} urls in #{Time.now - start_time}"

  ensure
    input.close if input && !input.closed? && !input.tty?
    output.close if output && !output.closed? && !output.tty?
  end
end
