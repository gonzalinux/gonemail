signature = <<137, 80, 78, 71, 13, 10, 26, 10>>

chunk = fn type, data ->
  crc = :erlang.crc32(type <> data)
  <<byte_size(data)::32, type::binary, data::binary, crc::32>>
end

ihdr = <<0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0>>
idat = :zlib.compress(<<0, 0, 0, 0, 0>>)
text = "Author\0@gonzalinux"
iend = <<>>

png =
  signature <>
    chunk.("IHDR", ihdr) <> chunk.("IDAT", idat) <> chunk.("tEXt", text) <> chunk.("IEND", iend)

File.write!("pixel.png", png)
IO.puts("Written pixel.png (#{byte_size(png)} bytes)")
IO.puts("Base64: #{Base.encode64(png)}")
