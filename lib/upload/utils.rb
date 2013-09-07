class Upload
  module Util
    def tmpdir(&block)
      return Dir.tmpdir unless block
      basename = [Process.ppid.to_s, Process.pid.to_s, Thread.current.object_id.abs.to_s, Time.now.to_f, rand.to_s].join('-')
      dirname = File.join(tmpdir, basename)
      FileUtils.mkdir_p(dirname)

      if block
        begin
          Dir.chdir(dirname){ return block.call(dirname) }
        ensure
          FileUtils.rm_rf(dirname) rescue "system rm -rf #{ dirname.inspect }"
        end
      else
        return(dirname)
      end
    end

    def retrying(*args, &block)
      options = args.extract_options!.to_options!

      n = Integer(args.shift || options[:n] || 8)

      last = n - 1

      n.times do |i|
        begin
          return block.call(i)
        rescue => e
          raise e if i == last
          sleep(rand * (2 ** i))
        end
      end
    end
    alias_method(:try_hard, :retrying)

    def absolute_path_for(*args)
      path = ('/' + paths_for(*args).join('/')).squeeze('/')
      path unless path.blank?
    end

    def relative_path_for(*args)
      path = absolute_path_for(*args).sub(%r{^/+}, '')
      path unless path.blank?
    end

    def normalize_path(arg, *args)
      absolute_path_for(arg, *args)
    end

    def paths_for(*args)
      path = args.flatten.compact.join('/')
      path.gsub!(%r|[.]+/|, '/')
      path.squeeze!('/')
      path.sub!(%r|^/|, '')
      path.sub!(%r|/$|, '')
      paths = path.split('/')
    end

    def args_for_arity(args, arity)
      arity = Integer(arity.respond_to?(:arity) ? arity.arity : arity)
      arity < 0 ? args.dup : args.slice(0, arity)
    end

    def bcall(block, args)
      argv = args_for_arity(args, block.arity)
      block.call(*argv)
    end

    def id
      ObjectId.new
    end

    def grid
      @grid ||= GridFS.namespace_for(:fs)
    end

    def s3
      Upload.exists('variants.s3'=>true)
    end

    def grid_fs
      Upload.exists('variants.grid_fs'=>true)
    end

    def extract_basename(object)
      filename = nil
      [:original_path, :original_filename, :path, :filename, :pathname].each do |msg|
        if object.respond_to?(msg)
          filename = object.send(msg)
          break
        end
      end
      cleanname(filename || object.to_s)
    end

    def cleanname(pathname)
      basename = ::File.basename(pathname.to_s)
      CGI.unescape(basename).gsub(%r/[^0-9a-zA-Z_@)(~.-]/, '_').gsub(%r/_+/,'_')
    end

    MIME_TYPES = {
      'md' => 'text/x-markdown; charset=UTF-8'
    }

    def extract_content_type(filename, options = {})
      options.to_options!

      basename = ::File.basename(filename.to_s)
      parts = basename.split('.')
      parts.shift
      ext = parts.pop

      default =
        case
          when options[:default]==false
            nil
          when options[:default]==true
            "application/octet-stream"
          else
            (options[:default] || "application/octet-stream").to_s
        end

      content_type = MIME_TYPES[ext] || MIME::Types.type_for(::File.basename(filename.to_s)).first

      if content_type
        content_type.to_s
      else
        default
      end
    end

    alias_method('content_type_for', 'extract_content_type')

    def extension_for_content_type(content_type)
      mime_types = MIME::Types[content_type.to_s]

      unless mime_types.blank?
        extension = Array(mime_types).first.extensions.first
      end
    end

    def image?(filename)
      content_type = extract_content_type(filename)
      content_type.to_s.split('/').include?('image')
    end

    extend(Util)
  end

  extend(Util)
end
