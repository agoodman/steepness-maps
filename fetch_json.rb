#!/usr/bin/ruby

require 'httparty'
require 'digest'

min_lat = 37.73
max_lat = 37.81
min_lng = -122.52
max_lng = -122.38

delta_lat = max_lat - min_lat
delta_lng = max_lng - min_lng

step_lat = 0.005
step_lng = 0.005

cells = []
lat = min_lat
while lat < max_lat
  lng = min_lng
  while lng < max_lng
    cells.push([lat,lng])
    lng = lng + step_lng
  end
  lat = lat + step_lat
end

intersections = []
cells.each do |e|
  url = "http://api.openstreetmap.org/api/0.6/map?bbox=#{e[1]},#{e[0]},#{e[1]+step_lat},#{e[0]+step_lng}"
  file = Digest::SHA1.hexdigest(url)
  
  puts url
  unless File.exist?("data/#{file}")
    open("data/#{file}", 'wb') do |out|
      out << HTTParty.get(url).to_json
    end
  end
end
