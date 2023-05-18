# frozen_string_literal: true

require_relative "Riftmaker/version"
require "uri"
require "net/http"
require "json"

module Riftmaker
  extend self

  # Raised when an HTTP request receives an unsuccessful status code
  class HttpRequestError < StandardError; end

  # Run Riftmaker to generate static data (currently only summoner emotes).
  # `summoner-emotes.json` will be created within the current directory upon success.
  def generate
    # Fetch locales list available
    # [ "default", "ja_jp"... ]
    global_folder_json = get_response("https://raw.communitydragon.org/json/latest/plugins/rcp-be-lol-game-data/global/")
    folder_hash = JSON.parse(global_folder_json)
    locales = folder_hash.map { |directory| directory["name"] }

    # Get every summoner emotes JSON file by locale
    aggregate_hash = {}
    locales.each do |locale|
      metadata_json = get_response("https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/#{locale}/v1/summoner-emotes.json")
      metadatas = JSON.parse(metadata_json)
      # Iterate over metadata array
      metadatas.each do |metadata|
        id = metadata["id"]
        name = metadata["name"]
        inventory_icon = metadata["inventoryIcon"]

        # Generate tags from inventory icon path
        regex = /(?<=[A-Z])(?=[A-Z][a-z])|(?<=[^A-Z])(?=[A-Z])|(?<=[A-Za-z])(?=[^A-Za-z])/
        tags = if inventory_icon.eql?("/lol-game-data/assets/")
                 []
               else
                 inventory_icon.sub("/lol-game-data/assets/ASSETS/Loadouts/SummonerEmotes/", "")
                               .split("/")
                               .reject { |tag| tag.include?(".png") }
                               .map do |tag|
                                 tag.sub("_", "")
                                    .split(regex)
                                    .join(" ")
                               end
               end

        aggregate_metadata = aggregate_hash.fetch(id, {})
        aggregate_metadata["id"] = id
        aggregate_metadata["inventoryIcon"] = if inventory_icon.eql?("/lol-game-data/assets/") || inventory_icon.eql?("")
                                                ""
                                              else
                                                path = inventory_icon.split("SummonerEmotes/")
                                                                     .map(&:downcase)
                                                "https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/assets/loadouts/summoneremotes/#{path.last}"
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
    File.open("summoner-emotes.json", "w") do |f|
      f.write(aggregate_hash.to_json)
    end
  end

  private

  def get_response(uri)
    uri = URI(uri)
    res = Net::HTTP.get_response(uri)
    raise HttpRequestError, "Response is not successful" unless res.is_a?(Net::HTTPSuccess)

    res.body
  end
end
