module Panoramic
  class PagesResolver < ActionView::Resolver
    require "singleton"
    include Singleton

    # this method is mandatory to implement a Resolver
    def find_templates(name, prefix, partial, details, key=nil, locals=[])
      return [] if @@resolver_options[:only] && !@@resolver_options[:only].include?(prefix)

      path = build_path(name, prefix)
      conditions = {
        :path    => path,
        :locale  => [normalize_array(details[:locale]).first, nil],
        :format  => normalize_array(details[:formats]),
        :handler => normalize_array(details[:handlers]),
        :partial => partial || false
      }.merge(details[:additional_criteria].presence || {})

      @@model.find_model_page_templates(conditions).map do |record|
        Rails.logger.debug "Rendering web page template from database: #{path} (#{record.format})"
        initialize_template(record)
      end
    end

    # Overide Rails actionview/lib/action_view/template/resolver.rb so we don't check cache
    # because we want to always read from database due to our multi-instance and multi tenant setup
    def cached(key, path_info, details, locals)
      name, prefix, partial = path_info

      if key
        # @cache.cache(key, name, prefix, partial, locals) do
          yield
        # end
      else
        yield
      end
    end

    # Instantiate Resolver by passing a model (decoupled from ORMs)
    def self.using(model, options={})
      @@model = model
      @@resolver_options = options
      self.caching = false
      self.instance
    end

    private

    # Initialize an ActionView::Template object based on the record found.
    def initialize_template(record)
      source = record.body
      identifier = "#{record.class} - #{record.id} - #{record.path.inspect}"
      handler = ActionView::Template.registered_template_handler(record.handler)

      details = {
        :format => Mime[record.format].to_sym,
        :updated_at => Time.now, # this avoids template cache for apartment gem tenants
        :virtual_path => virtual_path(record.path, record.partial)
      }

      ActionView::Template.new(source, identifier, handler, details)
    end

    # Build path with eventual prefix
    def build_path(name, prefix)
      prefix.present? ? "#{prefix}/#{name}" : name
    end

    # Normalize array by converting all symbols to strings.
    def normalize_array(array)
      array.map(&:to_s)
    end

    # returns a path depending if its a partial or template
    def virtual_path(path, partial)
      return path unless partial
      if index = path.rindex("/")
        path.insert(index + 1, "_")
      else
        "_#{path}"
      end
    end
  end
end
