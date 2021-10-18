# coding: utf-8

module Sanitize
  @@entities_decoder = HTMLEntities.new	# DB handles UTF-8/Unicode

  def sanitize(which, max_length)
    if self[which].nil?
      # preserve nil
      valid = true
    else
      original_length = self[which].length
      if self.respond_to?('feed') && self.feed.title == 'AustinGO RSS'
        self[which].gsub!(/â€™/, "\u{2019}")	# single right quote
        self[which].gsub!(/Â/, "\u{A0}")	# non-breaking space?
        self[which].gsub!(/👉/, "\u{261e}")	# right pointing hand, and maybe a skin tone character
        self[which].gsub!('&#039;', %q{'})
        self[which].encode!('UTF-8', invalid: :replace, undef: :replace)
      end
      valid = (original_length == self[which].length)
      # line below corrupts something and MariaDB barfs on 'Incorrect string value'
#      self[which] = @@entities_decoder.decode(self[which])
    end
    valid
  end
end
