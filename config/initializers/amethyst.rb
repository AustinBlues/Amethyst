# coding: utf-8
# These are named constants only the developer should change
#

# PAGINATION bitmasks
FEED_TOP = 0b1000
FEED_BOTTOM = 0b0100
POST_TOP = 0b0010
POST_BOTTOM = 0b0001

TOP_PAGINATION = FEED_TOP | POST_TOP	# PAGINATION default value 
BOTTOM_PAGINATION = FEED_BOTTOM | POST_BOTTOM


# HTML entities & Icons
ADD_ICON = SafeBuffer.new('&plus;')
BACK_ICON = SafeBuffer.new('&larr;')
DELETE_ICON = SafeBuffer.new('&minus;')
DOWN_VOTE_ICON = SafeBuffer.new('&darr;')
EDIT_ICON = "\u270E"
ELLIPSIS = "\u2026"
LAQUO = SafeBuffer.new('&laquo;')
LSAQUO = SafeBuffer.new('&lsaquo;')
RSAQUO = SafeBuffer.new('&rsaquo;')
RAQUO = SafeBuffer.new('&raquo;')
SEARCH_ICON = "\u{1F50E}"
#SWAP_ICON = '⇅'
SWAP_ICON = '↕'
#SWAP_ICON = "\u{1F5D8}"
TIMES = SafeBuffer.new('&times;')
#UNDO_ICON = "\u{21A9}"	# left hook arrow
UNDO_ICON = '↩'

# MySQL column limits
VARCHAR_MAX = 255
TEXT_MAX = 65535
