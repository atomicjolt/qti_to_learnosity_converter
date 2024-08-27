class ExportWriter
  def initialize(temp_file)
    @zip = Zip::File.open(temp_file.path, Zip::File::CREATE)
  end

  def close
    @zip.close
  end

  def write_to_zip(filename, content)
    @zip.get_output_stream(filename) do |file|
      file << content.to_json
    end
  end

  def write_asset_to_zip(filename, content)
    @zip.get_output_stream(filename) do |file|
      file << content
    end
  end
end
