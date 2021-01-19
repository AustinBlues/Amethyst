# These are named constants only the developer should change
#

# PAGINATION bitmasks
FEED_TOP = 0b1000
FEED_BOTTOM = 0b0100
POST_TOP = 0b0010
POST_BOTTOM = 0b0001

TOP_PAGINATION = FEED_TOP | POST_TOP	# PAGINATION default value 
BOTTOM_PAGINATION = FEED_BOTTOM | POST_BOTTOM


# HTML entities
DOWN_ARROW = SafeBuffer.new('&darr;')
EDIT_PENCIL = "\u270E"
ELLIPSIS = "\u2026"
LAQUO = SafeBuffer.new('&laquo;')
LSAQUO = SafeBuffer.new('&lsaquo;')
LEFT_ARROW = SafeBuffer.new('&larr;')
PLUS = SafeBuffer.new('&plus;')
RSAQUO = SafeBuffer.new('&rsaquo;')
RAQUO = SafeBuffer.new('&raquo;')
SEARCH = "\u{1F50E}"
TIMES = SafeBuffer.new('&times;')
UNDO = "\u21A9"		# leftward hook arrow

# MySQL column limits
VARCHAR_MAX = 255
TEXT_MAX = 65535
