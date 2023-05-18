# frozen_string_literal: true

require_relative "riftmaker/version"
require "uri"
require "net/http"
require "json"

module Riftmaker
  extend self
  TAG_REGEX = /(?<=[A-Z])(?=[A-Z][a-z])|(?<=[^A-Z])(?=[A-Z])|(?<=[A-Za-z])(?=[^A-Za-z])/.freeze
  URL_PATH = "https://raw.communitydragon.org"
  ASSETS_PATH = "/lol-game-data/assets/"
  LOCALES_PATH = "https://raw.communitydragon.org/json/latest/plugins/rcp-be-lol-game-data/global/"

  # Raised when an HTTP request receives an unsuccessful status code
  class HttpRequestError < StandardError; end

  # Run Riftmaker to generate static data (currently only summoner emotes).
  # `summoner-emotes.json` will be created within the current directory upon success.
  def generate
    # Get every summoner emotes JSON file by locale
    locales = get_locales(LOCALES_PATH)
    puts "Fetched locales list: #{locales}"
    aggregate_hash = {}
    locales.each do |locale|
      puts "Fetching for #{locale}..."
      metadata_json = get_response("#{URL_PATH}/latest/plugins/rcp-be-lol-game-data/global/#{locale}/v1/summoner-emotes.json")
      metadatas = JSON.parse(metadata_json)
      # Iterate over metadata array
      metadatas.each do |metadata|
        id = metadata["id"]
        name = metadata["name"]
        inventory_icon = metadata["inventoryIcon"]

        tags = get_tags(inventory_icon)

        aggregate_metadata = aggregate_hash.fetch(id, {})
        aggregate_metadata["id"] = id
        aggregate_metadata["inventoryIcon"] = if inventory_icon.eql?(ASSETS_PATH) || inventory_icon.eql?("")
                                                ""
                                              else
                                                path = inventory_icon.split("SummonerEmotes/")
                                                                     .map(&:downcase)
                                                "#{URL_PATH}/latest/plugins/rcp-be-lol-game-data/global/default/assets/loadouts/summoneremotes/#{path.last}"
                                              end
        aggregate_metadata["tags"] = tags

        aggregate_localized_names = aggregate_metadata.fetch("localizedNames", {})
        aggregate_localized_names[locale] = { name: name }
        aggregate_metadata["localizedNames"] = aggregate_localized_names

        aggregate_hash[id] = aggregate_metadata
      end
    end

    # Sort by ID and prepare aggregate
    aggregate_hash = aggregate_hash.sort_by { |k, _v| k }
                                   .to_h

    # Write aggregate metadata
    puts "Writing aggregate data to summoner-emotes.json..."
    File.open("summoner-emotes.json", "w") do |f|
      f.write(aggregate_hash.to_json)
    end
  end

  private

  # Generate tags from inventory icon path using string manipulation.
  def get_tags(inventory_icon)
    if inventory_icon.eql?(ASSETS_PATH)
      []
    else
      inventory_icon.sub("/lol-game-data/assets/ASSETS/Loadouts/SummonerEmotes/", "")
                    .split("/")
                    .reject { |tag| tag.include?(".png") }
                    .map do |tag|
                      tag.gsub("_", "")
                         .split(TAG_REGEX)
                         .join(" ")
                    end
    end
  end

  # Fetch locales list available
  # [ "default", "ja_jp"... ]
  def get_locales(path)
    global_folder_json = get_response(path)
    folder_hash = JSON.parse(global_folder_json)

    folder_hash.map { |directory| directory["name"] }
  end

  def get_response(uri)
    uri = URI(uri)
    res = Net::HTTP.get_response(uri)
    raise HttpRequestError, "Response is not successful" unless res.is_a?(Net::HTTPSuccess)

    res.body
  end
end
