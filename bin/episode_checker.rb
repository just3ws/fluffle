# frozen_string_literal: true

require 'amazing_print'
require 'csv'

def find_episodes(directory)
  episodes = []

  Dir.foreach(directory) do |file|
    next if file.start_with?('.') # Skip hidden files and directories

    path = File.join(directory, file)

    if File.directory?(path)

      # .converted
      converted = File.exist?(File.join(path, '.converted'))
      # .distributed
      distributed = File.exist?(File.join(path, '.distributed'))
      # .downloaded
      downloaded = File.exist?(File.join(path, '.downloaded'))
      # .transcribed
      transcribed = File.exist?(File.join(path, '.transcribed'))
      # episode.mp3
      mp3 = File.exist?(File.join(path, 'episode.mp3'))
      # episode.srt
      srt = File.exist?(File.join(path, 'episode.srt'))
      # episode.txt
      txt = File.exist?(File.join(path, 'episode.txt'))
      # episode.vtt
      vtt = File.exist?(File.join(path, 'episode.vtt'))
      # episode.wav
      wav = File.exist?(File.join(path, 'episode.wav'))
      # episode.xml
      xml = File.exist?(File.join(path, 'episode.xml'))
      # transcribe.log
      log = File.exist?(File.join(path, 'transcribe.log'))

      if converted || distributed || downloaded || log || mp3 || srt || transcribed || txt || vtt || wav || xml
        episodes << { path:, converted:, distributed:, downloaded:, log:, mp3:, srt:, transcribed:, txt:, vtt:, wav:,
                      xml: }
      else
        episodes.concat(find_episodes(path))
      end
    end
  end

  episodes
end

def generate_csv(array_of_hashes)
  return if array_of_hashes.empty?

  keys = array_of_hashes.first.keys

  CSV.generate do |csv|
    csv << keys
    array_of_hashes.each do |hash|
      csv << hash.values_at(*keys)
    end
  end
end

require 'builder'

# def generate_html(array_of_hashes)
#   return if array_of_hashes.empty?
#
#   html = Builder::XmlMarkup.new(indent: 2)
#   html.html do
#     html.head do
#       html.style 'table { border-collapse: collapse; }'
#       html.style 'th, td { border: 1px solid black; padding: 5px; }'
#     end
#     html.body do
#       html.table do
#         html.tr do
#           array_of_hashes.first.keys.each do |key|
#             html.th key.to_s.capitalize
#           end
#         end
#         array_of_hashes.each do |hash|
#           html.tr do
#             hash.each_value do |value|
#               html.td value
#             end
#           end
#         end
#       end
#     end
#   end
#
#   html.target!
# end

def generate_html(array_of_hashes)
  return if array_of_hashes.empty?

  html = Builder::XmlMarkup.new(indent: 2)

  html.html do
    html.head do
      html.meta(charset: 'utf-8')
      html.meta(name: 'viewport', content: 'width=device-width, initial-scale=1')
      html.link(rel: 'stylesheet', href: 'https://cdn.jsdelivr.net/npm/milligram@1.4.1/dist/milligram.min.css')
      html.style <<~CSS
        .truthy { background-color: green; text-transform: uppercase; color: white; font-weight: bold; text-align: center; }
        .falsey { background-color: red; text-transform: uppercase; color: white; font-weight: bold; text-align: center; }
      CSS
    end

    html.body do
      html.div(class: 'container') do
        html.table(class: 'table') do
          html.thead do
            html.tr do
              array_of_hashes.first.each_key do |key|
                html.th key.to_s.capitalize
              end
            end
          end

          html.tbody do
            array_of_hashes.each do |hash|
              html.tr do
                hash.each_value do |value|
                  if value.to_s == 'true' || value.to_s == 'false'
                    css_class = value ? 'truthy' : 'falsey'
                    html.td(value.to_s[0], class: css_class)
                  else
                    html.td(value)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  html.target!
end

directory = File.expand_path('~/podcasts/dead-rabbit-radio/episodes/')
episodes = find_episodes(directory)
# markdown_table = generate_markdown_table(episodes)
puts generate_html(episodes)

# puts markdown_table
