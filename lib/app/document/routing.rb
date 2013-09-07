module App
  module Document
    code_for 'app/document/routing' do
      def self.route(params = {}, options = {})
        options.to_options!
        scope = options[:scope] || all

        conditions = Map.new

        case params
          when Hash
            params.to_options!
            conditions.update(params.slice(:slug, :id, :_id))
          else
            conditions.update(:slug => params.to_s, :id => params.to_s)
        end

        id = conditions[:_id] || conditions[:id]
        slug = conditions[:slug]

        id_or_slug = id || slug
        slug_or_id = slug || id

        conditions[:slug] ||= Slug.for(id_or_slug)
        conditions[:_id] ||= slug_or_id
        conditions[:id] ||= slug_or_id

        scope.any_of(conditions.map{|k,v| {k => v}}).first or not_found!(conditions)
      end
    end
  end
end
