# -*- coding: utf-8 -*-
module TAPI
  module V3
    class Client
      include Configurable
      
      require 'uri'
      require 'digest'
      require 'curl'
      require 'json'
      require 'logger'
      
      attr_reader :etag, :document
      
      HTTP_ERRORS = {
        302 => MovedError,
        205 => ExpiredError,
        401 => InternalServerError,
        404 => NotFoundError,
        500 => InternalServerError
      }
      
      class << self
        
        def http_authentication
          self.class.http_authentication
        end
        
        def new_from_post(url, params)
          curl, server_etag = execute_request(:post, url, params)
          new(JSON.parse(curl.body_str), nil, true)
        end
        
        def new_from_get(url, options = {}, etag = nil)
          klass = options.delete(:instanciate_as) || self
          curl, server_etag = execute_request(:get, url, options, etag)

          if server_etag && etag == server_etag
            logger.debug "Known ETag."
            [nil, server_etag]
          else
            logger.debug "Unknown ETag."
            [klass.new(JSON.parse(curl.body_str), server_etag, true), server_etag]
          end
        end
        
        def check_for_errors(curl)
          error_class = HTTP_ERRORS[curl.response_code]
          error_class ||= Error if (401..599).include?(curl.response_code)

          if error_class
            error = error_class.new
            error.request_url = curl.url
            error.response_code = curl.response_code
            error.response_body = curl.body_str
            raise error 
          end
        end

        def parse_etag(str)
          str.split("\r\n").grep(/^etag/i).first.split(' ').last if str =~ /^etag/i
        end

        def execute_request(method, url, params, etag = nil)
          url = base_url + url
          url = Utils.append_query(url, params) if Hash === params and method == :get
          
          curl = Curl::Easy.new(url)
          
          if auth = http_authentication
            curl.userpwd = auth
          end
          
          curl.headers["If-None-Match"] = etag if etag
          
          server_etag = nil          

          time = Time.now
          case method
          when :get
            curl.http_get
            server_etag = parse_etag(curl.header_str)
            
          when :post
            fields = params.to_a.map {|key, value| Curl::PostField.content(key.to_s, value.to_s)}

            curl.http_post(fields)
          end

          logger.debug "TAPI #{method.to_s.upcase} #{Time.now - time} #{url} #{params.inspect} #{etag} #{server_etag}"
          
          check_for_errors(curl)          

          [curl, server_etag]
        end
        
        
        def logger
          Thread.current[:tapi_logger] || Logger.new(STDOUT)
        end

        def logger=(logger)
          Thread.current[:tapi_logger] = logger
        end

        def base_url
          config[:base_url] || ""
        end
        
        def http_authentication
          if config[:http_password] && config[:http_user_name]
            "#{config[:http_user_name]}:#{config[:http_password]}"
          else
            nil
          end
        end

        
      end # end class methods

      def initialize(hash, etag = nil, is_root = false)
        @document = {}
        @etag = etag if etag

        update(hash)
      end
      
      def logger
        self.class.logger
      end

      undef id if instance_methods.include?('id')

      def to_hash
        @document.inject({}) do |hash, (key, val)|
          hash[key] = \
          case val
          when Client then val.to_hash
          when Array then val.map {|v| Client === v ? v.to_hash : v }
          else val
          end
          hash
        end
      end

      def to_json
        to_hash.to_json
      end

      def attributes
        @document.keys.map(&:to_s)
      end

      def urls
        if search = @document[:search]
          search.urls
        elsif @document[:resources]
          @document[:resources].to_hash
        else
          Hash.new
        end
      end

      def remote_calls
        urls.keys.map{|resource| "fetch_#{/(.*)_url$/.match(resource.to_s)[1]}"}.sort
      end
      
      def to_param
        id
      end
      
      def respond_to?(key, include_private = false)
        @document.has_key?(key) or
          urls["#{url_key(key)}_url".to_sym] or
          super(key, include_private)
      end
      
      def class_mapping
        config[:class_mapping] ||= {}
      end

      protected

      def update(hash)
        hash.each do |key, value|
          @document[key.to_sym] = \
          case value
          when Hash
            client_class(key).new(value)
          when Array
            klass = client_class(key)
            value.map { |e| Hash === e ? klass.new(e) : e }
          when String
            if value.respond_to?(:force_encoding)
              value.force_encoding(Encoding::UTF_8)
            else
              value
            end
          else
            value
          end
        end
      end

      def method_missing(key, *args)
        if @document.has_key?(key)
          @document[key]
        else
          if url = urls["#{url_key(key)}_url".to_sym]
            options = args.first || {}
            get(url, client_class(key), options)
          else
            raise NoMethodError, "undefined method `#{key}' for #{self.class}", caller
          end
        end
      end

      def url_key(key)
        (match = /^fetch_(.*)/.match(key.to_s)) && match[1]
      end

      def remote_cache
        @remote_cache ||= {}
      end

      def get(url, klass, options = {})
        cache_key = cache_key(url, options)
        cached_reply = remote_cache[cache_key]

        return cached_reply[:data] if options.delete(:skip_refresh) and cached_reply
        old_etag =  cached_reply ? cached_reply[:etag] : nil

        if options.delete(:skip_cache)
          return self.class.new_from_get(url, options.merge(:instanciate_as => klass), nil).first
        end

        data, etag = self.class.new_from_get(url, options.merge(:instanciate_as => klass), old_etag)

        if etag && etag == old_etag
          logger.debug "ETag match. Returning data from internal cache."
          remote_cache[cache_key][:data]
        else
          logger.debug "Returning fetched data."
          if etag
            remote_cache[cache_key] = {:data => data, :etag => etag}
          end
          data
        end
      end

      def cache_key(url, options)
        Digest::MD5.hexdigest(url.to_s + options.to_a.sort {|a, b| a.first.to_s <=> b.first.to_s }.flatten.join)
      end      

      def client_class(name)
        class_mapping[name.to_sym] || Client
      end 

    end
  end
end
