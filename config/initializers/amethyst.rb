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
#BACK_ICON = SafeBuffer.new('&larr;')
BACK_ICON = "\u{2190}"
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
#SWAP_ICON = '↕'
#SWAP_ICON = "\u{1F5D8}"
#SWAP_ICON = SafeBuffer.new('<img src="cycle.png" alt="Cycle thru indexes" style="width:32px;height:32px;">')
SWAP_ICON = "\u{21c4}"
TIMES = SafeBuffer.new('&times;')
#TO_FEED_ICON = "\u{25B2}"	# up pointing triangle
TO_FEED_ICON = "\u{21c6}"
#TO_POST_ICON = "\u{25BC}"	# down pointing triangle
TO_POST_ICON = "\u{21c4}"
#UNDO_ICON = "\u{21A9}"	# left hook arrow
UNDO_ICON = '↩'

# MySQL column limits
VARCHAR_MAX = 255
TEXT_MAX = 65535
