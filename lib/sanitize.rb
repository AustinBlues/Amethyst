# coding: utf-8

module Sanitize
  @@entities_decoder = HTMLEntities.new	# DB handles UTF-8/Unicode

  def sanitize!(which, max_length)
    sanitized = false
    if self[which]
      self[which].gsub!("\u{1F449}", "\u{261E}")	# MariaDB doesn't accept Unicode white right pointing index
      sanitized ||= !$~.nil?
      original_length = self[which].length
      self[which] = @@entities_decoder.decode(self[which])
      sanitized ||= (original_length != self[which].length)
    end
    sanitized
  end
end
