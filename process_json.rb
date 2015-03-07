#!/usr/bin/ruby

require 'json'
require 'csv'
require 'polylines'
require 'httparty'
require 'digest'

def latlng(val)
  intval = (val.to_f * 1e5).to_i
  (intval / 1e5).to_f
end

all_nodes = {}
all_roads = []

# flag to control batching of points
batch_points = true
batch_size = 128

# base url for elevation api
base_url = "https://maps.googleapis.com/maps/api/elevation/json?key=#{ENV['ELEVATION_API_KEY']}&locations=enc:"

files = Dir.entries("data").reject {|e| e=='.' || e=='..'}
puts "collecting raw data"
files.each do |filename|
  file = File.open("data/#{filename}")
  json = JSON.parse(file.read) rescue {}
  file.close
  
  nodes = json["osm"]["node"] || [] rescue []
  nodes.each {|node| all_nodes[node["id"]] = {"lat"=>latlng(node["lat"]), "lon"=>latlng(node["lon"])} unless !node.is_a?(Hash)}

  ways = json["osm"]["way"] || [] rescue []
  
  # find roads - ways tagged highway=trunk|primary|secondary|tertiary|residential
  roads = ways.select {|way| way["tag"]!=nil && way["tag"].any? {|tag| tag["k"]=="highway" && ([tag["v"]] & ["trunk","primary","secondary","tertiary","residential"]).any? rescue false}} rescue []
  all_roads += roads
end
puts "found #{all_roads.count} roads"

puts "building terrain requests"
num_points = 0
requests = []
# save point data to a file for use in visualization
CSV.open("output/points.csv", "wb") do |csv|
  polyline_points = []
  all_roads.each do |way|
    road_name = way["tag"].select {|tag| tag["k"]=="name" rescue false}.first["v"] rescue nil
    next if road_name.nil?
    
    if batch_points && (polyline_points.count + way["nd"].count > batch_size)
      encoded_points = Polylines::Encoder.encode_points(polyline_points)
      requests << encoded_points
      polyline_points.clear
    end
    
    way["nd"].each do |e|
      node = all_nodes[e["ref"]]
      puts "weird node: (#{node["lat"]}, #{node["lon"]})" if !node["lat"].is_a?(Float) || !node["lon"].is_a?(Float)
      csv << [road_name, node["lat"], node["lon"]]
      polyline_points << [node["lat"], node["lon"]]
      num_points += 1
    end
    
    if !batch_points
      encoded_points = Polylines::Encoder.encode_points(polyline_points)
      requests << encoded_points
      polyline_points.clear
    end
  end
  
  # add another request to pick up any remaining points
  if polyline_points.count > 0
    requests << Polylines::Encoder.encode_points(polyline_points)
  end
end

CSV.open("output/requests.csv", "wb") do |csv|
  requests.each {|req| csv << [req]}
end
puts "found #{requests.count} requests totaling #{num_points} points"

puts "consolidating elevation data"
elevations = []
road_index = 0
path_index = 0
requests.each do |req|
  escaped_url = URI::escape(base_url+req)
  rsp = HTTParty.get(escaped_url)
  file = Digest::SHA1.hexdigest(req)
  unless File.exist?("results/#{file}.json")
    File.open("results/#{file}.json", "wb") do |f|
      f.write rsp.body
    end
  end
end
