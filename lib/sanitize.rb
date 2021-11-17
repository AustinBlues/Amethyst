# coding: utf-8

module Sanitize
  @@entities_decoder = HTMLEntities.new	# DB handles UTF-8/Unicode

  def sanitize!(which, max_length)
    if self[which].nil?
      sanitized = false
    else
      sanitized = false
      if self.respond_to?('feed') && self.feed.title == 'AustinGO RSS'
        # Workarounds for AustinGO RSS feed mangled encoding.  Delete when fixed.
        self[which].gsub!(/â€™/, "\u{2019}")	# single right quote
        sanitized ||= !$~.nil?
        self[which].gsub!(/Â/, "\u{A0}")	# non-breaking space
        sanitized ||= !$~.nil?
#        self[which].gsub!(/👉/, "\u{1F449}")	# white right pointing index (Incorrect string value on MariaDB)
        self[which].gsub!(/👉/, "\u{261E}")	# right pointing index
        sanitized ||= !$~.nil?
        self[which].encode!('UTF-8', invalid: :replace, undef: :replace)
        sanitized ||= !$~.nil?
      end
      self[which].gsub!("\u{1F449}", "\u{261E}")	# MariaDB doesn't accept Unicode white right pointing index
      sanitized ||= !$~.nil?
      original_length = self[which].length
      self[which] = @@entities_decoder.decode(self[which])
      sanitized ||= (original_length != self[which].length)
    end
    sanitized
  end
end
