#!/usr/bin/ruby

require 'json'
require 'nokogiri'

def haversine(lat1,lng1,lat2,lng2)
  radius = 6371000
  phi1 = lat1 * Math::PI / 180.0
  phi2 = lat2 * Math::PI / 180.0
  delta_phi = phi2 - phi1
  delta_lam = (lng2 - lng1) * Math::PI / 180.0
  sdp = Math.sin(delta_phi / 2.0)
  sdl = Math.sin(delta_lam / 2.0)
  a = sdp * sdp + Math.cos(phi1) * Math.cos(phi2) * sdl * sdl
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  return radius * c
end

def grade_color(grade)
  abs_grade = grade.abs
  if abs_grade<2
    return "ff00ff00"
  elsif abs_grade<10
    return "ff00ffff"
  elsif abs_grade<20
    return "ff00aaff"
  else
    return "ff0000ff"
  end
end

puts "processing elevation data"
files = Dir.entries("results").reject {|e| e=='.' || e=='..'}
segments = []
files.each do |filename|
  file = File.open("results/#{filename}")
  json = JSON.parse(file.read) rescue {}
  file.close
  results = (json["results"] || [] rescue [])
  for k in (1..results.count-1)
    p1 = results[k-1]["location"]
    p2 = results[k]["location"]
    run = haversine(p1["lat"], p1["lng"], p2["lat"], p2["lng"])
    rise = results[k]["elevation"] - results[k-1]["elevation"]
    grade = 100.0 * rise / run
    # puts "%.5f,%.5f,%.1f -> %.5f,%.5f,%.1f rise: %.1f run: %.1f grade: %.2f%%" % [p1["lat"],p1["lng"],results[k-1]["elevation"],p2["lat"],p2["lng"],results[k]["elevation"],rise,run,grade]
    if run > 10 && run < 200
      segments << [p1["lat"],p1["lng"],results[k-1]["elevation"],p2["lat"],p2["lng"],results[k]["elevation"],rise,run,grade]
    end
  end
end

segments.each_slice(100000).with_index do |chunk,index|
  builder = Nokogiri::XML::Builder.new do |doc|
    doc.kml('xmlns' => 'http://earth.google.com/kml/2.0') {
      doc.Document {
        chunk.each do |seg|
          doc.Placemark {
            doc.LineString {
              doc.coordinates "#{seg[1]},#{seg[0]},#{seg[2]} #{seg[4]},#{seg[3]},#{seg[5]}"
            }
            doc.Style {
              doc.LineStyle {
                doc.width 5
                doc.color grade_color(seg[8])
              }
            }
          }
        end
      }
    }
  end
  kml_file = File.open("overlays/chunk#{index}.kml", "wb")
  kml_file.write(builder.to_xml)
  kml_file.close
end
puts "wrote #{segments.count} placemarks"
