require "./url_filter/*"

module URLFilter
  def self.run
    abort "usage: #{$0} <blacklist_file> <whitelist_file> < <url_file>" \
      unless ARGV.size == 2

    blacklist = whitelist = nil
    begin
      blacklist = Array(URLFilter::Rule).from_json(File.read(ARGV[0]))
      whitelist = Array(URLFilter::Rule).from_json(File.read(ARGV[1]))
    rescue e: Exception
      abort "ERROR: #{e.message} (#{e.class.name})"
    end
    abort "No filter was defined" unless blacklist && whitelist

    STDERR.puts "loaded blacklist: #{blacklist.size} rules, "\
      "whitelist: #{whitelist.size} rules"

    blacklist = URLFilter::Filter.new(blacklist).optimize!
    whitelist = URLFilter::Filter.new(whitelist).optimize!

    STDERR.puts "optimized blacklist: #{blacklist.size} rules, "\
      "whitelist: #{whitelist.size} rules"

    count = 0
    start_time = Time.now
    STDIN.each_line do |url|
      STDOUT.puts url \
        if !whitelist.match?(url) || blacklist.match?(url)
      count += 1
    end
    STDOUT.flush
    STDERR.puts "done filtering #{count} urls in #{Time.now - start_time}"
  end
end
