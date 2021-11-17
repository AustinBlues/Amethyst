# These are parameters the user can set
#
PAGE_SIZE = ENV['PAGE_SIZE'] && (Padrino.env != :test) ? ENV['PAGE_SIZE'].to_i : 8

# How many days to keep zombies (Posts that have been dropped from their Feed)
DAYS_OF_THE_DEAD = 34

# How many Unread post to keep visible
UNREAD_LIMIT = 100

# Minimum Words In Common required
WIC_MIN = ENV['WIC_MIN'] ? ENV['WIC_MIN'].to_i : 4

# Maximum Related Posts
RELATED_POSTS_MAX = ENV['RELATED_POSTS_MAX'] ? ENV['RELATED_POSTS_MAX'].to_i : 5

# How many Word frequency and count (Post specfic) to display beside the description (zero to not display them)
DISPLAY_WORDS = ENV['DISPLAY_WORDS'] ? ENV['DISPLAY_WORDS'].to_i : 12

# How many days for Feed score Exponential Moving Average (EMA)
# Twice as long between posts of least frequent post is a good starting value
EMA_DAYS = 7
ALPHA = 2.0/(EMA_DAYS + 1.0)	# don't change unless you really understand EMA and know a better way

PAGINATION = ENV['AMETHYST_PAGINATION'] && (Padrino.env != :test) ? ENV['AMETHYST_PAGINATION'].to_i(2) : TOP_PAGINATION
PAGINATED = (PAGINATION != 0)

ROOT = ENV['ROOT'] || ENV['PWD'].split('/').last
