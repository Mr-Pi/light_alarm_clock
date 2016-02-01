return function(connection, req, args)
	if req.method=="POST" or req.method=="PUT" then
		local data=req.getRequestData()
		rtctime.set(data.time,0)
		print("time is now set to: "..tostring(rtctime.get()))
		ok, json = pcall(cjson.encode, data.alarms)
		if not ok then
			print("failed to encode alarm array to json")
		else
			if not file.open("http/alarm.json","w+") then
				print("failed to write alarm.json")
			else
				file.write(json)
				file.close()
			end
		end
		connection:send("HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nCache-Control: private, no-store\r\n\r\n")
		connection:send("{\"okay\":true}")
		ok=nil
		json=nil
		data=nil
	end
	collectgarbage()
end
