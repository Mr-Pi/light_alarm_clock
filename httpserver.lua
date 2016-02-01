-- httpserver
-- Author: Marcos Kirsch

-- Starts web server in the specified port.
return function (port)

   local s = net.createServer(net.TCP, 10) -- 10 seconds client timeout
   s:listen(
      port,
      function (connection)

         -- This variable holds the thread used for sending data back to the user.
         -- We do it in a separate thread because we need to yield when sending lots
         -- of data in order to avoid overflowing the mcu's buffer.
         local connectionThread
        
         local allowStatic = {GET=true, HEAD=true, POST=false, PUT=false, DELETE=false, TRACE=false, OPTIONS=false, CONNECT=false, PATCH=false}

         local function startServing(fileServeFunction, connection, req, args) 
            local bufferedConnection = {}
            connectionThread = coroutine.create(function(fileServeFunction, bconnection, req, args)
               fileServeFunction(bconnection, req, args)
               if not bconnection:flush() then
	         connection:close()
                 connectionThread = nil
 	       end
            end)
            function bufferedConnection:flush() 
              if self.size > 0 then 
		connection:send(table.concat(self.data, ""))
                self.data = {}
                self.size = 0    
		return true
	      end
	      return false
            end
            function bufferedConnection:send(payload) 
              local l = payload:len()
              if l + self.size > 1000 then
                 if self:flush() then
                   coroutine.yield()          
		 end
              end
	      if l > 800 then
		connection:send(payload)
		coroutine.yield()
	      else
                table.insert(self.data, payload)
                self.size = self.size + l
              end
            end
            bufferedConnection.size = 0
            bufferedConnection.data = {}
            local status, err = coroutine.resume(connectionThread, fileServeFunction, bufferedConnection, req, args)
            if not status then
               print(err)
            end
         end

         local function onRequest(connection, req)
            collectgarbage()
            local method = req.method
            local uri = req.uri
            local fileServeFunction = nil
            
            print("Method: " .. method);
            
            if #(uri.file) > 32 then
               -- nodemcu-firmware cannot handle long filenames.
               uri.args = {code = 400, errorString = "Bad Request"}
               fileServeFunction = dofile("httpserver-error.lc")
            else
               local fileExists = file.open(uri.file, "r")
               file.close()
            
               if not fileExists then
                 -- gzip check
                 fileExists = file.open(uri.file .. ".gz", "r")
                 file.close()

                 if fileExists then
                    print("gzip variant exists, serving that one")
                    uri.file = uri.file .. ".gz"
                    uri.isGzipped = true
                 end
               end

               if not fileExists then
                  uri.args = {code = 404, errorString = "Not Found"}
                  fileServeFunction = dofile("httpserver-error.lc")
               elseif uri.isScript then
                  fileServeFunction = dofile(uri.file)
               else
                  if allowStatic[method] then
                    uri.args = {file = uri.file, ext = uri.ext, gzipped = uri.isGzipped}
                    fileServeFunction = dofile("httpserver-static.lc")
                  else
                    uri.args = {code = 405, errorString = "Method not supported"}
                    fileServeFunction = dofile("httpserver-error.lc")
                  end
               end
            end
            startServing(fileServeFunction, connection, req, uri.args)
         end

         local function onReceive(connection, payload)
            collectgarbage()
            local conf = dofile("httpserver-conf.lc")
            local auth
            local user = "Anonymous"

	    -- as suggest by anyn99 (https://github.com/marcoskirsch/nodemcu-httpserver/issues/36#issuecomment-167442461)
	    -- collect data packets until the size of http body meets the Content-Length stated in header
	    if payload:find("Content%-Length:") or bBodyMissing then
		    if tmp_payload then tmp_payload = tmp_payload .. payload else tmp_payload = payload end
		    if (tonumber(string.match(tmp_payload, "%d+", tmp_payload:find("Content%-Length:")+16)) > #tmp_payload:sub(tmp_payload:find("\r\n\r\n", 1, true)+4, #tmp_payload)) then
			    bBodyMissing = true
			    return
		    else
			    print("HTTP packet assembled! size: "..#tmp_payload)
			    payload = tmp_payload
			    tmp_payload, bBodyMissing = nil    
		    end
	    end
	    collectgarbage()

            -- parse payload and decide what to serve.
            local req = dofile("httpserver-request.lc")(payload)
            print("Requested URI: " .. req.request)
            if conf.auth.enabled then
               auth = dofile("httpserver-basicauth.lc")
               user = auth.authenticate(payload) -- authenticate returns nil on failed auth
            end

            if user and req.methodIsValid and (req.method == "GET" or req.method == "POST" or req.method == "PUT") then
               onRequest(connection, req)
            else
               local args = {}
               local fileServeFunction = dofile("httpserver-error.lc")
               if not user then
                  args = {code = 401, errorString = "Not Authorized", headers = {auth.authErrorHeader()}}
               elseif req.methodIsValid then
                  args = {code = 501, errorString = "Not Implemented"}
               else
                  args = {code = 400, errorString = "Bad Request"}
               end
               startServing(fileServeFunction, connection, req, args)
            end
         end

         local function onSent(connection, payload)
            collectgarbage()
            if connectionThread then
               local connectionThreadStatus = coroutine.status(connectionThread) 
               if connectionThreadStatus == "suspended" then
                  -- Not finished sending file, resume.
                  local status, err = coroutine.resume(connectionThread)
                  if not status then
                     print(err)
                  end
               elseif connectionThreadStatus == "dead" then
                  -- We're done sending file.
                  connection:close()
                  connectionThread = nil
               end
            end
         end

         connection:on("receive", onReceive)
         connection:on("sent", onSent)

      end
   )
   -- false and nil evaluate as false
   local ip = wifi.sta.getip()
   if not ip then ip = wifi.ap.getip() end
   print("nodemcu-httpserver running at http://" .. tostring(ip) .. ":" ..  tostring(port))
   ip=nil
   collectgarbage()

   return s
end
