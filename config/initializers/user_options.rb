STDERR.puts "ARGV: #{ARGV.inspect}."
task = if 'resque:work'.start_with?(ARGV[0])
         :background
       elsif 'start'.start_with?(ARGV[0])
         :web_server
       elsif Padrino.env == :test
         :test
       elsif 'run'.start_with?(ARGV[0])
         :daily
       elsif 'console'.start_with?(ARGV[0])
         :console
       else
         nil
       end
STDERR.puts "TASK: #{task}."

# These are parameters the user can set
#
PAGE_SIZE = ENV['PAGE_SIZE'] && (Padrino.env != :test) ? ENV['PAGE_SIZE'].to_i : 8
STDERR.puts("PAGE_SIZE: #{PAGE_SIZE}.") if task == :web_server || task == :test

# How many days to keep zombies (Posts that have been dropped from their Feed)
DAYS_OF_THE_DEAD = ENV['DAYS_OF_THE_DEAD'] ? ENV['DAYS_OF_THE_DEAD'].to_i : 34
STDERR.puts("DAYS_OF_THE_DEAD: #{DAYS_OF_THE_DEAD}.") if task == :background || task == :daily || task == :test

# How many Unread post to keep visible
UNREAD_LIMIT = ENV['UNREAD_LIMIT'] ? ENV['UNREAD_LIMIT'].to_i : 100
STDERR.puts("UNREAD_LIMIT: #{UNREAD_LIMIT}.") if task == :background

# Minimum Words In Common required
WIC_MIN = ENV['WIC_MIN'] ? ENV['WIC_MIN'].to_i : 4
STDERR.puts("WIC_MIN: #{WIC_MIN}.") if task == :web_server

# Maximum Related Posts
RELATED_POSTS_MAX = ENV['RELATED_POSTS_MAX'] ? ENV['RELATED_POSTS_MAX'].to_i : 5
STDERR.puts("RELATED_POSTS_MAX: #{RELATED_POSTS_MAX}.") if task == :web_server

# How many Word frequency and count (Post specfic) to display beside the description (zero to not display them)
DISPLAY_WORDS = ENV['DISPLAY_WORDS'] ? ENV['DISPLAY_WORDS'].to_i : 12
STDERR.puts("DISPLAY_WORDS: #{DISPLAY_WORDS}.") if task == :web_server

# What to do with sludge
SLUDGE_ACTION = ENV['SLUDGE_ACTION'] || 'HIDDEN'
STDERR.puts("SLUDGE_ACTION: #{SLUDGE_ACTION}.") if task == :background

# How many days for Feed score Exponential Moving Average (EMA)
# Twice as long between posts of least frequent post is a good starting value
EMA_DAYS = ENV['EMA_DAYS'] ? ENV['EMA_DAYS'].to_i : 7
STDERR.puts("EMA_DAYS: #{EMA_DAYS}.") if task == :web_server || task == :background
ALPHA = 2.0/(EMA_DAYS + 1.0)	# don't change unless you really understand EMA and know a better way

PAGINATION = ENV['AMETHYST_PAGINATION'] && (Padrino.env != :test) ? ENV['AMETHYST_PAGINATION'].to_i(2) : TOP_PAGINATION
STDERR.puts("PAGINATION: #{PAGINATION.to_s(2)}b.") if task == :web_server || task == :test
PAGINATED = (PAGINATION != 0)

ROOT = ENV['ROOT'] || ENV['PWD'].split('/').last
