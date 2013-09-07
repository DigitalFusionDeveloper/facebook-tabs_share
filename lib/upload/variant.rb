class Upload
  class Variant
  ##
  #
    if defined?(App::Document)
      include App::Document
    else
      include Mongoid::Document
      include Mongoid::Timestamps
    end

  ##
  #
    field(:name, :default => 'original', :type => String)
    field(:basename, :type => String)
    field(:title, :type => String)
    field(:default, :default => proc{ name == 'original' })

    field(:content_type, :type => String)
    field(:length, :type => Integer)
    field(:md5, :type => String)

    field(:grid_fs, :type => Hash)
    field(:s3, :type => Hash)
    field(:fs, :type => Hash)

    field(:headers, :type => Hash)

  ##
  #
    validates_presence_of(:name)
    validates_presence_of(:basename)
    validates_presence_of(:content_type)
    validates_presence_of(:length)
    validates_presence_of(:md5)

  ##
  #
    embedded_in(:upload, :class_name => '::Upload')

  ##
  #
    before_validation do |variant|
      if variant.title.blank?
        variant.title = variant.default_title
      end
    end

  ##
  #
    before_destroy do |variant|
      if variant.grid_fs?
        variant.grid_fs_file.destroy rescue nil
      end

      if variant.s3?
        variant.s3_object.delete rescue nil
      end

      true
    end

  ##
  #
    def filename
      basename
    end

    def title
      title = read_attribute(:title)

      if title.blank?
        default_title
      else
        title
      end
    end

    def default_title
      basename.split('.', 2).first.titleize
    end

  ##
  #
    def grid_fs_file
      if grid_fs?
        namespace = GridFS.namespace_for(grid_fs['prefix'])
        namespace.get(grid_fs['file_id'])
      end
    end

    def grid_fs?
      !grid_fs.blank?
    end

  ##
  #
    def fs?
      !fs.blank?
    end

  ##
  #
    def s3?
      !s3.blank?
    end

    def to_s3(*args, &block)
      variant = self
      options = args.extract_options!.to_options!

      bucket = args.shift || options[:bucket] || Upload.config.get(:aws, :s3, :bucket) or raise(ArgumentError, 'no bucket')
      key = args.shift || options[:key] || Upload.relative_path_for(path) or raise(ArgumentError, 'no key')
      acl = args.shift || options[:acl] || :public_read

      bucket = aws_s3.buckets[bucket]

      object = bucket.objects[key]

      on_disk do |fullpath|
        object.write(:file => fullpath, :content_type => content_type, :acl => acl)
      end

      update_attributes!(
        'tmp' => false,
        's3' => {'bucket' => bucket.name, 'key' => object.key}
      )

      if block
        Upload.bcall(block, [object, variant, upload])
      else
        object
      end
    end

    def remove_from_grid_fs!
      if grid_fs?
        grid_fs_file.destroy
        unset(:grid_fs)
      end
    end

    def to_s3!(*args, &block)
      remove_from_grid_fs! if to_s3(*args, &block)
    end

    def aws_s3
      AWS::S3.new
    end

    def s3_bucket
      return nil unless s3?
      aws_s3.buckets[s3['bucket']]
    end

    def s3_object
      return nil unless s3?
      s3_bucket.objects[s3['key']]
    end

  ##
  #
    def local?
      grid_fs? || fs?
    end

    def remote?
      s3?
    end

    def original?
      name.to_s == 'original'
    end

  ##
  #
    def data(&block)
      case
        when grid_fs?
          block ? grid_fs_file.each(&block) : grid_fs_file.data

        when s3?
          s3_object.read(&block)

        when fs?
          pathname = File.join(fs['root'] || Upload.config.get(:fs, :root), fs['path'])

          if block
            ::File.open(pathname, 'rb') do |fd|
              while((buf = fd.read(8192)))
                block.call(buf)
              end
            end
          else
            IO.binread(pathname)
          end
      end
    end

    def on_disk(&block)
      variant = self
      upload.variant_on_disk(variant, &block)
    end

    def open(*args, &block)
      on_disk(*args) do |basename|
        File.open(basename, 'rb') do |fd|
          block.call(fd)
        end
      end
    end

  ##
  #
    def headers_for(headers)
      if self.headers.blank?
        {}
      else
        self.headers
      end
    end

    def data_uri(*args, &block)
      base64 = Array(data).pack('m')
      data = base64.chomp
      "data:#{ content_type };base64,".concat(data)
    end

    def image?
      content_type.to_s.split('/').include?('image')
    end
  end

  embeds_many(:variants, :class_name => '::Upload::Variant', :cascade_callbacks => true) do
    def destroy_all
      each do |variant|
        variant.destroy unless variant.original?
      end
    end

    def find_by_name(name)
      where(:name => name.to_s).first
    end

    def find_by_name!(name)
      find_by_name(name) or Variant.not_found!(:name => name)
    end

    def for(arg)
      case arg
        when Variant
          where(:_id => arg.id).first
        else
          where(:name => arg.to_s).first
      end
    end

    def for!(arg)
      variant = self.for(arg)

      unless variant
        case arg
          when Variant
            Variant.not_found!(:_id => arg.id)
          else
            Variant.not_found!(:name => arg.to_s)
        end
      end

      variant
    end

    def original
      find_by_name(:original)
    end

    def default
      where(:default => true).first || original
    end
  end

  before_destroy do |upload|
    upload.variants.destroy_all
    true
  end
end
