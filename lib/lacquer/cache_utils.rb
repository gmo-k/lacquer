module Lacquer
  module CacheUtils
    def self.included(base)
      base.class_eval do
        attr_reader :cache_ttl

        if respond_to? :before_action
          before_action :set_default_cache_ttl
          after_action :send_cache_control_headers
        elsif respond_to? :before_filter
          before_filter :set_default_cache_ttl
          after_filter :send_cache_control_headers
        end
      end
    end

    # Instance variable for the action ttl.
    def set_cache_ttl(ttl)
      @cache_ttl = ttl
    end

    # Called as a before filter to set default ttl
    # for the entire application.
    def set_default_cache_ttl
      set_cache_ttl(Lacquer.configuration.default_ttl)
    end

    # Sends url.purge command to varnish to clear cache.
    #
    # clear_cache_for(root_path, blog_posts_path, '/other/content/*')
    def clear_cache_for(*paths)
      return unless Lacquer.configuration.enable_cache
      case Lacquer.configuration.job_backend
      when :delayed_job
        require 'lacquer/delayed_job_job'
        Delayed::Job.enqueue(Lacquer::DelayedJobJob.new(paths))
      when :resque
        require 'lacquer/resque_job'
        Resque.enqueue(Lacquer::ResqueJob, paths)
      when :sidekiq
        require 'lacquer/sidekiq_worker'
        Lacquer::SidekiqWorker.perform_async(paths)
      when :none
        Varnish.new.purge(*paths)
      end
    end

    # Sends cache control headers with page.
    # These are the headers that varnish responds to
    # to set cache properly.
    def send_cache_control_headers
      if Lacquer.configuration.enable_cache && @cache_ttl && @cache_ttl != 0
        expires_in(@cache_ttl, :public => true)
      end
    end
  end
end
