-- httpserver-static.lua
-- Part of nodemcu-httpserver, handles sending static files to client.
-- Author: Marcos Kirsch

return function (connection, req, args)
   dofile("httpserver-header.lc")(connection, 200, args.ext, args.gzipped)
   --print("Begin sending:", args.file)
   -- Send file in little chunks
   local continue = true
   local bytesSent = 0
   while continue do
      collectgarbage()
      -- NodeMCU file API lets you open 1 file at a time.
      -- So we need to open, seek, close each time in order
      -- to support multiple simultaneous clients.
      file.open(args.file)
      file.seek("set", bytesSent)
      local chunk = file.read(256)
      file.close()
      if chunk == nil then
         continue = false
      else
         connection:send(chunk)
         bytesSent = bytesSent + #chunk
         chunk = nil
         tmr.wdclr() -- loop can take a while for long files. tmr.wdclr() prevent watchdog to restart module
         --print("Sent" .. args.file, bytesSent)
      end
   end
   --print("Finished sending:", args.file)
end
