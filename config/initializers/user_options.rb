# These are parameters the user can set
#
PAGE_SIZE = 8

# How many days to keep zombies (Posts that have been dropped from their Feed)
DAYS_OF_THE_DEAD = ENV['DAYS_OF_THE_DEAD'] ? ENV['DAYS_OF_THE_DEAD'].to_i : 33

# How many Unread Posts to keep visible
UNREAD_LIMIT = ENV['UNREAD_LIMIT'] ? ENV['UNREAD_LIMIT'].to_i : 50

# Minimum Words In Common required
WIC_MIN = ENV['WIC_MIN'] ? ENV['WIC_MIN'].to_i : 4

# Maximum Related Posts
RELATED_POSTS_MAX = ENV['RELATED_POSTS_MAX'] ? ENV['RELATED_POSTS_MAX'].to_i : 5

# How many Word frequency and count (Post specfic) to display beside the description (zero to not display them)
DISPLAY_WORDS = ENV['DISPLAY_WORDS'] ? ENV['DISPLAY_WORDS'].to_i : 12

# Exponential Moving Average (EMA) period for Feed scores and volume
# Twice as long between posts of least frequent blogger posts is a good starting value
EMA_DAYS = 60
ALPHA = 2.0/(EMA_DAYS + 1.0)	# don't change unless you know Exponential Moving Average very well

PAGINATION = ENV['AMETHYST_PAGINATION'] ? ENV['AMETHYST_PAGINATION'].to_i(2) : TOP_PAGINATION
PAGINATED = PAGINATION != 0

# Prefix used to make Redis and databases unique to a Amethyst server
ROOT = ENV['ROOT'] || ENV['PWD'].split('/').last
