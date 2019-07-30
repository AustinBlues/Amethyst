YAML.load(File.read('seeds.yml')).each do |f|
  feed = Feed.create(rss_url: f[:rss_url], title: f[:title])
end
