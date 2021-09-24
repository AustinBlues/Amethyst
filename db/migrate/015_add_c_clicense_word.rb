Sequel.migration do
  STOP_WORDS = %w{Creative Commons NonCommercial License Attribution licensed sell copy share ISSN ISBN}

  up do
    STOP_WORDS.each do |sw|
      from(:words).where(name: sw).update(flags: 2)
    end
  end

  down do
    STOP_WORDS.each do |sw|
      from(:words).where(name: sw).update(flags: 0)
    end
  end
end
