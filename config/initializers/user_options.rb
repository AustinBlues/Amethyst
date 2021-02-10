# These are parameters the user can set
#
PAGE_SIZE = 8

# How many days to keep zombies (Posts that have been dropped from their Feed)
DAYS_OF_THE_DEAD = 34

# How many Unread post to keep visible
UNREAD_LIMIT = 50

# How many days for Feed score Exponential Moving Average (EMA)
# How long between posts of least frequent post is a good starting value
EMA_DAYS = 30


PAGINATION = ENV['AMETHYST_PAGINATION'] ? ENV['AMETHYST_PAGINATION'].to_i(2) : TOP_PAGINATION
PAGINATED = (PAGINATION != 0)
ROOT = ENV['ROOT'] || ENV['PWD'].split('/').last

