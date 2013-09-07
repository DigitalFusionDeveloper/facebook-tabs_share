require 'open-uri'
require 'mime/types'
require 'digest/md5'
require 'rails_default_url_options'
require 'fattr'
require 'map'

# TODO - extract as an engine...

class Upload
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
  if defined?(::Mongoid::GridFS) and not defined?(GridFS)
    GridFS = ::Mongoid::GridFS
  end

  if defined?(::Moped::BSON) and not defined?(BSON)
    BSON = ::Mopend::BSON
  end

  if defined?(::Moped::BSON::ObjectId) and not defined?(ObjectId)
    ObjectId = ::Moped::BSON::ObjectId
  end

##
#
  belongs_to(:context, :polymorphic => true)

##
#
  field(:key, :type => String)
  field(:basename, :type => String)
  field(:strategy, :type => String, :default => proc{ Upload.config.get(:strategy) || 'grid_fs' })
  field(:tmp, :type => Boolean, :default => false)
  field(:headers, :type => Hash, :default => proc{ {} })
  field(:roles, :type => Array, :default => proc{ [] })
  field(:acl, :type => String, :default => 'public')

##
#
  validates_presence_of(:basename)
  validates_presence_of(:strategy)
  validates_uniqueness_of(:key, :allow_nil => true)

##
#
  index({'key' => 1}, {:sparse => true})
  index({'variants.grid_fs' => 1})
  index({'variants.s3' => 1})
  index({'updated_at' => 1})
  index({'tmp' => 1})

##
#
  scope(:tmp, where(:tmp => true))

##
#
  load 'upload/config.rb'
  load 'upload/utils.rb'
  load 'upload/routes.rb'
  load 'upload/helper.rb'
  load 'upload/processing.rb'
  load 'upload/tmpwatch.rb'
  load 'upload/sio.rb'
  load 'upload/cache.rb'
  load 'upload/placeholder.rb'

  load 'upload/variant.rb'
  load 'upload/url_for.rb'

##
# upload creation support
#
# /system/uploads/ 1234567890/original/logo.png
# /system/uploads/ 1234567890/small/logo.png
#
# FIXME - factor out Storage/Strategy class (strategy pattern) with exists/get/put/destroy interface
#
  def add_variant(name, io_or_path, options = {})
    upload = self

    options.to_options!

    name         = name.to_s.downcase.to_sym
    basename     = options[:basename] || options[:filename] || Upload.extract_basename(io_or_path)
    content_type = options[:content_type] || Upload.extract_content_type(basename)

    path = "#{ Upload.route }/#{ id }/#{ name }/#{ basename }"

    strategy = options[:strategy] || upload.strategy

    attributes = {
      'name'         => name,
      'basename'     => basename,
      'strategy'     => strategy
    }

    case strategy
    #
      when 'grid_fs', ''
        options[:grid_fs] ||= {}

        Upload.grid[path].tap{|existing| existing.delete if existing}

        grid_fs_file =
          begin
            Upload.try_hard do
              Upload.grid.put(io_or_path, :filename => path)
            end
          rescue Object
            raise "failed up put #{ [io_or_path, options].inspect } into grid_fs"
          end

        attributes.update({
          'grid_fs' => {
            'prefix'  => grid_fs_file.namespace.prefix,
            'file_id' => grid_fs_file.id
          },

          'content_type' => grid_fs_file.content_type,
          'length'       => grid_fs_file.length,
          'md5'          => grid_fs_file.md5
        })

    #
      when 's3'
        options[:s3] ||= {}

        bucket = 
          options[:s3][:bucket] ||
          Upload.config.get(:aws, :s3, :bucket) ||
          Upload.config.get(:s3, :bucket) ||
          Upload.config.get(:bucket)
          
        raise(ArgumentError, 'no bucket') unless bucket

        acl = options[:s3][:acl] || :public_read

        key = Upload.relative_path_for(path)

        s3 = AWS::S3.new

        bucket = s3.buckets[bucket]

        object = bucket.objects[key]

        content_type = options[:content_type] || Upload.extract_content_type(path)

        Upload.try_hard do
          object.write(:file => io_or_path, :acl => acl, :content_type => content_type)
        end

        length = object.content_length
        md5 = object.etag.gsub(%r/["']/, '')

        attributes.update({
          's3' => {
            'bucket' => bucket.name,
            'key'    => object.key
          },

          'content_type' => content_type,
          'length'       => length,
          'md5'          => md5
        })

    #
      when 'fs'
        options[:fs] ||= {}

        root = options[:fs][:root]

        prefix = (root || Upload.config.get(:fs, :root) || Rails.root.join('public')).to_s

        dst = File.expand_path(File.join(prefix, path))

        tmp = dst + ".#{ Process.pid }.#{ Process.ppid }.#{ rand }.upload"

        src = nil
        opened = false

        case
          when io_or_path.respond_to?(:read)
            src = io_or_path
          else
            src = open(io_or_path, 'rb')
            opened = true
        end

        md5 = Digest::MD5.new

        begin
          FileUtils.mkdir_p(File.dirname(tmp))

          open(tmp, 'wb+') do |fd|
            begin
              while((buf = src.read(8192)))
                md5 << buf
                fd.write(buf)
              end
            ensure
              src.close if opened
            end
          end

          FileUtils.mv(tmp, dst)
        ensure
          FileUtils.rm_rf(tmp)
        end

        content_type = options[:content_type] || Upload.extract_content_type(path)
        length       = File.stat(dst).size
        md5          = md5.hexdigest

        attributes.update({
          'fs' => {
            'root'  => root,
            'path'  => path
          },

          'content_type' => content_type,
          'length'       => length,
          'md5'          => md5
        })
    end

  #
    variants.where(:name => name).first.try(:destroy)

    variant = variants.build(attributes)

    upload.basename ||= variant.basename

  #
    variant
  end

  def add_variant!(*args, &block)
    variant = add_variant(*args, &block)
    save!
    reload
    variant
  end

  def upload(*args, &block)
    variants.destroy_all
    add_variant(:original, *args, &block)
  end

  def upload!(*args, &block)
    upload(*args, &block)
  ensure
    save! unless $!
  end

  def to_s3(*args, &block)
    variants.map do |variant|
      variant.to_s3(*args, &block)
      variant
    end
  end

  def to_s3!(*args, &block)
    variants.map do |variant|
      variant.to_s3!(*args, &block)
      variant
    end
  end

##
#
  def Upload.upload(*args, &block)
    new.tap{|u| u.upload(*args, &block)}
  end

  def Upload.upload!(*args, &block)
    new.tap{|u| u.upload!(*args, &block)}
  end

  def Upload.io(*args, &block)
    new.tap{|u| u.upload(*args, &block)}
  end

  def Upload.io!(*args, &block)
    new.tap{|u| u.upload!(*args, &block)}
  end

  def Upload.sio(*args, &block)
    sio = SIO.for(*args)
    new.tap{|u| u.upload(sio, &block)}
  end

  def Upload.sio!(*args, &block)
    sio = SIO.for(*args)
    new.tap{|u| u.upload!(sio, &block)}
  end

  def Upload.from_url!(url, &block)
    basename = Upload.cleanname(File.basename(url.to_s.split('?').first))
    upload = nil

    open(url, 'rb') do |socket|
      content_type = socket.content_type rescue nil

      if content_type and content_type != Upload.extract_content_type(basename)
        ext = Upload.extension_for_content_type(content_type)
        if ext
          base = basename.split('.').first
          basename = "#{ base }.#{ ext }"
        end
      end

      Upload.tmpdir do
        Upload.try_hard do
          open(basename, 'wb') do |fd|
            while((buf = socket.read(8192)))
              fd.write(buf)
            end
          end
        end

        open(basename, 'rb') do |io|
          upload = Upload.io!(io, :basename => basename)
        end
      end
    end

    block ? block.call(upload) : upload
  end

  def Upload.to_s3(*args, &block)
    args.push(options = args.extract_options!.to_options!)

    queries = Array(options.delete(:uploads))
    
    if queries.empty?
      not_on_s3 = Upload.where('tmp' => false, 'variants.s3' => nil)
      queries.push(not_on_s3)
    end

    results = []

    queries.each do |query|
      query.each do |upload|
        upload.to_s3(*args, &block)
        upload.reload
        results.push(upload) unless block
      end
    end

    block ? nil : results
  end

  def Upload.to_s3!(*args, &block)
    args.push(options = args.extract_options!.to_options!)

    stable_for = options[:stable_for] || Upload.config.stable_for

    stable_at = Time.now.utc - stable_for.to_i

    queries = Array(options.delete(:uploads))

    if queries.empty?
      queries.push(
        Upload.where('tmp' => false, 'variants.s3' => nil, 'updated_at' => { '$lt' => stable_at })
      )
    end

    results = []

    queries.each do |query|
      query.each do |upload|
        stable           = upload.updated_at < stable_at

        upload.to_s3(*args, &block)

        all_on_s3 = upload.variants.all?{|variant| variant.s3?}

        if(stable and all_on_s3)
          upload.update_attributes!(:strategy => 's3')
          upload.remove_from_grid_fs!

          block ? block.call(upload) : results.push(upload)
        end
      end
    end

    block ? nil : results
  end

  def Upload.create_from_s3_url!(url, options = {})
  #
    options = Map.for(options)

  #
    uri = Addressable::URI.parse(url.to_s.split('?').first)
    basename = File.basename(uri.to_s)

  #
    s3 = Map.new

    s3[:protocol] = uri.scheme
    s3[:host] = uri.host

    relative_path = uri.path.sub(%r|\A/+|, '')

    case 
      when s3.host =~ /\A(.*)\.s3(.*)\.amazonaws\.com\Z/
        bucket = $1
        key = relative_path

      when s3.host =~ /\As3(.*)\.amazonaws\.com\Z/
        parts = relative_path.split('/')
        bucket = parts.shift
        key = parts.join('/')

      else
        raise(ArgumentError, url.to_s)
    end

    s3[:bucket] = bucket
    s3[:key]= key

  #
    attributes = Map.new(
      :strategy => 's3',
      :key      => "s3://#{ bucket }/#{ key }",
      :variant  => Map.new
    )

    key_path = Upload.absolute_path_for(key)
    route_path = Upload.absolute_path_for(Upload.route)

    if key_path.starts_with?(route_path)
      id, name, basename = key_path.split('/').last(3)
      attributes[:id] = id
      attributes[:variant][:name] = name
      attributes[:variant][:basename] = basename
      attributes[:basename] = basename
    else
      attributes[:variant][:basename] = basename
      attributes[:basename] = basename
    end

    object = AWS::S3.new.buckets[s3[:bucket]].objects[s3[:key]]

    content_type = object.content_type

    if content_type.blank?
      content_type = Upload.extract_content_type(basename)
      acl = object.acl.to_s
      object.copy_from(object, :content_type => content_type)
      object.acl = acl
    end

    length = object.content_length
    md5 = object.etag.gsub(/['"]/, '')

    attributes[:variant][:content_type] = content_type
    attributes[:variant][:length] = length
    attributes[:variant][:md5] = md5

    attributes[:variant][:s3] = s3

    variant_attributes = attributes.delete(:variant)
    variant_attributes.update(options.get(:attributes, :variant) || {})

  #
    upload = new(attributes.merge(options[:attributes] || {}))

    variant = upload.variants.build(variant_attributes)

    if attributes[:id]
      upload.id = attributes[:id]
    end

    upload.save!

    upload
  end

##
#
  def filename
    basename
  end

  def url_for(*args, &block)
    variants.url_for(*args, &block)
  end

  def url(*args, &block)
    url_for(*args, &block)
  end

  def urls(*args, &block)
    variants.map{|variant| variant.url(*args, &block)}
  end

  def s3_url_for(*args, &block)
    variants.s3_url_for(*args, &block)
  end

  def s3_url(*args, &block)
    s3_url_for(*args, &block)
  end

  def s3_urls(*args, &block)
    variants.map{|variant| variant.s3_url(*args, &block)}
  end


  def path_for(*args, &block)
    variants.path_for(*args, &block)
  end

  def path(*args, &block)
    path_for(*args, &block)
  end

  def paths(*args, &block)
    variants.map{|variant| variant.path(*args, &block)}
  end

  def headers_for(headers)
    if self.headers.blank?
      {}
    else
      self.headers
    end
  end

##
#
  def grid_fs_files
    variants.map{|variant| variant.grid_fs_file}.compact
  end

  def grid_fs_file_chunks
    grid_fs_files.map{|grid_fs_file| grid_fs_file.chunks}.compact.flatten
  end

  def remove_from_grid_fs!
    variants.all.map{|variant| variant.remove_from_grid_fs!}
  end

##
#
  def original
    variants.original
  end

  def variant_and_args_for(*args)
    options = args.extract_options!.to_options!
    name = args.shift || options.delete(:name)

    variant = variants.find_by_name(name) || original

    args.push(options) unless options.empty?

    [variant, args]
  end

  %w(
    data title

    data_url data_uri

    url_for url

    grid_fs_url_for grid_fs_url

    s3_url_for s3_url

    fs_url_for fs_url

    path_for path
  ).each do |method|
    module_eval <<-__, __FILE__, __LINE__

      def #{ method }(*args, &block)
        variant, args = variant_and_args_for(*args)

        variant.#{ method }(*args) if variant
      end

    __
  end

##
#
  def grid_fs?
    variants.any?{|variant| variant.grid_fs?}
  end

  def s3?
    variants.any?{|variant| variant.s3?}
  end

  def fs?
    variants.any?{|variant| variant.fs?}
  end

  def image?
    variants.any?{|variant| variant.image?}
  end


##
#
  def as_json(*args, &block)
    upload = self

    json = upload.as_document

    json['id'] = upload.id
    json['url'] = path
    json['filename'] = upload.filename
    json['title'] = upload.title
    json['is_image'] = upload.image?
    json['sizes'] = {}

    variants.each_with_index do |variant, index|
      json['variants'][index]['id'] = variant.id
      json['variants'][index]['url'] = variant.path
      json['variants'][index]['is_image'] = variant.image?

      json['variants'][index]['filename'] = upload.filename
      json['variants'][index]['basename'] = upload.basename
      json['variants'][index]['title'] = upload.title
    end

    json
  end

  def tmp!(tmp = true)
    update_attributes(:tmp => tmp)
  end

##
#
# FIXME: test resizing now...
#
  def variants_for(*args, &block)
    [].tap do |variants|

      args.each do |arg|
        case arg
          when Variant
            variants.push(arg)
          when String, Symbol
            variants.push(self.variants.any_of({:name => arg}, {:id => arg}).first)
          else
            variants.push(self.variants.find(arg))
        end
      end

      variants.compact!
      variants.uniq!
    end
  end

  def tmpdir(&block)
    @tmpdir ||= nil

    if @tmpdir
      return block.call(@tmpdir)
    else
      Upload.tmpdir do |tmpdir|
        variants_on_disk.clear
        @tmpdir = tmpdir

        begin
          return block.call(@tmpdir)
        ensure
          variants_on_disk.clear
          @tmpdir = nil
        end
      end
    end
  end

  def variants_on_disk
    @variants_on_disk ||= Map.new
  end

  def on_disk(*args, &block)
    variants = variants_for(*args)

    if variants.blank?
      variants = self.variants.to_a
    end

    tmpdir do
      variants.each do |variant|
        variant_on_disk!(variant)
      end

      block.call(variants_on_disk) if block
    end
  end

  def variant_on_disk!(variant, &block)
    variant = variants.for!(variant)

    fullpath = variants_on_disk[variant.name]

    if fullpath
      return(block ? block.call(fullpath) : fullpath)
    end

    tmpdir do
      pathname = File.join(variant.name, variant.basename)

      ::FileUtils.mkdir_p(::File.dirname(pathname))

      ::File.open(pathname, 'wb') do |fd|
        variant.data{|chunk| fd.write(chunk)}
      end

      fullpath = File.expand_path(pathname)
      variants_on_disk[variant.name] = fullpath

      return(block ? block.call(fullpath) : fullpath)
    end
  end

  def variant_on_disk(variant, &block)
    variant = variants.for!(variant)

    on_disk(variant) do
      fullpath = variants_on_disk[variant.name]
      block.call(fullpath)
    end
  end
end
