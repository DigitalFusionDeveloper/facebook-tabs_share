{

  File.join(Rails.root, 'lib/git/hooks/pre-commit') => File.join(Rails.root, '.git/hooks/pre-commit')

}.each do |src, dst|
  if test(?e, src) and not test(?e, dst)
    FileUtils.cp(src, dst)
  end
end


