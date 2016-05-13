-- vim: ts=4 sw=4
--
-- timer used:
--	2: time sync (30min)
--	3: time checker for alarm (20sec)
local time = require "time"
local dimmer = require "dimmer"
local alarm={}
local syncs={successfully=0,failed=0}

local function syncreport(msg)
	print("time sync: "..msg)
	print("        "..
	      "(successfully:"..syncs.successfully..
	            ",failed:"..syncs.failed..")")
end

function alarm.sync()
	net.dns.resolve("ntp.selfnet.de", function(sk, ip)
		if not ip then
			syncs.failed=syncs.failed+1
			syncreport("failed to resolve ntp dns record")
		else
			sntp.sync("1.pool.ntp.org",
			function(sec,usec,server)
				syncs.successfully=syncs.successfully+1
				h,m,s,wd = time.get(sec)

				syncreport("successfully "..
				           "("..h..":"..m..":"..s..","..wd..")")
			end,
			function()
				syncs.failed=syncs.failed+1
				syncreport("failed")
			end)
		end
	end)
	collectgarbage()
end

function alarm.checker()
	local ok = file.open("http/alarm.json")
	if not ok then
		print("failed to read alarm.json")
	else
		local timers = file.read()
		ok, timers = pcall(function() return cjson.decode(timers) end)
		if not ok then
			print("failed to parse alarm.json")
		else
			for i=1,#timers do
				local h,m,s,wd = time.get(rtctime.get())
				if h==tonumber(string.sub(timers[i].time,1,2)) and
				   m==tonumber(string.sub(timers[i].time,4,5)) and
				   timers[i].days[tostring(wd)] then
					dimmer.set(100)
					dimmer.reset(10*60*1000)
					print("execute alarm: "..timers[i].time)
				end
				collectgarbage()
			end
		end
	end
	file.close()
	collectgarbage()
end	

function alarm.init()
	dimmer.init()
	alarm.sync()
	tmr.alarm(2, 1000*1800, tmr.ALARM_AUTO, function()
		alarm.sync()
	end)
	tmr.alarm(3, 1000*20, tmr.ALARM_AUTO, function()
		ok, _ = pcall(function() alarm.checker() end)
		if not ok then
			print("failed to execute alarm checker!")
		end
	end)
end

return alarm
