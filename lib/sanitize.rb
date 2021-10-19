# coding: utf-8

module Sanitize
  @@entities_decoder = HTMLEntities.new	# DB handles UTF-8/Unicode

  def sanitize(which, max_length)
    if self[which].nil?
      valid = true
    else
      original_length = self[which].length
      if self.respond_to?('feed') && self.feed.title == 'AustinGO RSS'
        # Workarounds for AustinGO RSS feed mangled encoding.  Delete when fixed.
        self[which].gsub!(/â€™/, "\u{2019}")	# single right quote
        self[which].gsub!(/Â/, "\u{A0}")	# non-breaking space
        self[which].gsub!(/👉/, "\u{261e}")	# white right pointing index
        self[which].encode!('UTF-8', invalid: :replace, undef: :replace)
      end
      valid = (original_length == self[which].length)
      self[which] = @@entities_decoder.decode(self[which])
    end
    valid
  end
end
