tmr.alarm(0, 10000, tmr.ALARM_SINGLE, function()
	print("starting light alarm clock")
	dofile("init.org.lua")
end)
