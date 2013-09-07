module App
  module Document
    code_for 'app/document/archive' do
    ## archival support via boolean archived flag
    #
      scope(:archived, where(:archived => true)) unless respond_to?(:archived)
      scope(:unarchived, where('$or' => [{:archived => false}, {:archived => {'$exists' => false}}])) unless respond_to?(:unarchived)
       
      def archive!
        set(:archived, true)
        self
      end

      def unarchive!
        unset(:archived)
        self
      end

      def archived?
        self[:archived]
      end
    end
  end
end
