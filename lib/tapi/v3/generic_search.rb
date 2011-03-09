# -*- coding: utf-8 -*-
module TAPI
  module V3
    class GenericSearch
      
      extend Validations

      attr_reader :client, :client_urls, :started_at, :start_time
      attr_accessor :errors

      def id
        if @id
          @id
        elsif @client and @client.respond_to?(:id)
          @client.id
        end
      end

      def id=(id)
        @id = id
      end

      include Configurable
      include Utils
      
      def add_error(name, message)
        (errors[name] ||= []) << message
      end

      def valid?
        errors.clear

        self.class.inherited_validations.each do |validation|
          instance_eval(&validation)
        end

        errors.empty?
      end

      def has_errors?
        errors.any?
      end

      def reload
        load_client
        self
      end

      def api_url
        port = config[:port] == 80 ? '' : ":#{config[:port]}"
        "http://#{ config[:host] }#{ port }#{ config[:path] }"
      end
      
      def api_key
        config[:key]
      end
      
      def post_url
        api_url + '/' + item_path + '/searches.json'
      end

      def get(path, options={})
        TAPI::V3::Client.new_from_get(api_url + path + '.json', options.merge(:key => api_key)).first
      end
      
      def start!
        @started_at = Time.now
        @client = TAPI::V3::Client.new_from_post(post_url, parameters).search
        @start_time = Time.now - @started_at
        @client_urls = @client.urls
      end
      
      def load_client
        if @client_urls
          client, etag = TAPI::V3::Client.new_from_get(@client_urls[:search_url], {}, @etag)
          @client, @etag = client.search, etag unless @etag == etag
        end
      end
      
      def restart!
        if @client_urls
          TAPI::V3::Client.new_from_post(@client_urls[:restart_url], {})
          load_client
        end
      end
      
      def method_missing(key, *args)
        begin
          @client.send(key, *args)
        rescue NoMethodError
          raise NoMethodError, "undefined method `#{key}' for #{self.class}", caller
        end
      end
      
    end
  end
end
