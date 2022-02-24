Sequel.migration do
  HTML = 4
  # List of common HTML tags and attributes encountered
  html = %w{alt img border width height hspace vspace usemap target http https title src png jpg
       imgs p svg a b br span div style a font size value color weight rel table cellspacing
       cellpadding colspan rowspan align valign href h1 h2 h3 h4 figure figcaption class block
       image large content sub max nofollow link}

  up do
    html.each do |w|
      if from(:words).where(name: w, flags: 0).update(flags: HTML) == 0
        from(:words).insert(name: w, flags: HTML)
      end
    end
  end

  down do
    html.each do |w|
      from(:words).where(name: w, flags: HTML).update(flags: 0)
    end
  end
end
