# -*- coding: utf-8 -*-
module TAPI
  module V3
    module Configurable

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      def config
        Thread.current[:tapi_config] ||= {}
      end
    
      module ClassMethods

        def config
          Thread.current[:tapi_config] ||= {}
        end

        def config=(config)
          Thread.current[:tapi_config] = config
        end
      end
        
    end
  end
end
