-- v012621_0
local Heartbeat = game:GetService("RunService").Heartbeat
local timerClass = {}
timerClass.__index = timerClass
-- Constructor
function timerClass.new(startTime)
	local timer = {
		_startTime = type(startTime)=="number" and startTime or 60,
		_compensation = 0,
		_running = false,
		_loopEnabled = false,
		_InternalStop = Instance.new("BindableEvent"),
		_Started = Instance.new("BindableEvent"),
		_Paused = Instance.new("BindableEvent"),
		_Stopped = Instance.new("BindableEvent"),
		_Ended = Instance.new("BindableEvent"),
		_WasSet = Instance.new("BindableEvent"),
	}
	timer._timeLeft = timer._startTime
	timer.Started = timer._Started.Event
	timer.Paused = timer._Paused.Event
	timer.Stopped = timer._Stopped.Event
	timer.Ended = timer._Ended.Event
	timer.WasSet = timer._WasSet.Event
	setmetatable(timer,timerClass)
	return timer
end
-- Methods
function timerClass:Start(compensationMode)
	if not self:IsRunning() then
		local TimerLoop, InternalStop, StopFlag, LastTick
		if compensationMode then
			self._timeLeft = self._timeLeft - self._compensation
		end
		InternalStop = self._InternalStop.Event:Connect(function(StopTag)
			StopFlag = StopTag
		end)
		TimerLoop = Heartbeat:Connect(function()
			local DeltaTime = os.clock()-LastTick
			LastTick = os.clock()
			if not StopFlag then
				self._timeLeft = self._timeLeft-DeltaTime
			end
			local TimedOut = self._timeLeft <= 0
			if TimedOut or StopFlag then
				self._running = false
				InternalStop:Disconnect()
				TimerLoop:Disconnect()
				if (StopFlag == "End") or TimedOut then
					if TimedOut then
						self._compensation = math.abs(self._timeLeft)
					end
					self._timeLeft = self._startTime
					self._Ended:Fire()
					if self._loopEnabled and TimedOut then
						while (self._compensation >= self._startTime) and self._loopEnabled do
							self._Started:Fire()
							self._Ended:Fire()
							self._compensation -= self._startTime
						end
						if self._loopEnabled then
							self:Start(true)
						end
					end
				elseif StopFlag == "Pause" then
					self._Paused:Fire()
				elseif StopFlag == "Stop" then
					self._timeLeft = self._startTime
					self._Stopped:Fire()
				end
			end
		end)
		self._running = true
		LastTick = os.clock()
		self._Started:Fire()
	end
end

function timerClass:Pause()
	if self:IsRunning() then
		self._InternalStop:Fire("Pause")
	end
end

function timerClass:Stop()
	if self:IsRunning() then
		self._InternalStop:Fire("Stop")
	elseif self._timeLeft < self._startTime then
		self._timeLeft = self._startTime
		self._Stopped:Fire()
	end
end

function timerClass:End()
	if self:IsRunning() then
		self._InternalStop:Fire("End")
	elseif self._timeLeft < self._startTime then
		self._timeLeft = self._startTime
		self._Ended:Fire()
	end
end

function timerClass:Set(startTime,noReset)
	self._startTime = type(startTime)=="number" and startTime or self._startTime
	if noReset then
		self._timeLeft = math.min(self._timeLeft,self._startTime)
	else
		self._timeLeft = self._startTime
	end
	self._WasSet:Fire()
end

function timerClass:EnableLooping()
	self._loopEnabled = true
end

function timerClass:DisableLooping()
	self._loopEnabled = false
end

function timerClass:GetTimeLeft()
	return self._timeLeft
end

function timerClass:GetStartTime()
	return self._startTime
end

function timerClass:IsRunning()
	return self._running
end
-- Other functions
function timerClass.Schedule(startTime,callback,loop)
	if not (type(callback) == "function") then
		return
	end
	local timer = timerClass.new(startTime)
	local EndEvent
	if loop then
		EndEvent = timer.Ended:Connect(function()
			callback()
			timer:Start(true)
		end)
	else
		EndEvent = timer.Ended:Connect(callback)
	end
	timer:Start()
	return EndEvent, timer
end

function timerClass.Wait(n)
	local initialTick = os.clock()
	local currentTick
	repeat
		Heartbeat:Wait()
		currentTick = os.clock()
	until currentTick-initialTick >= (n or 0)
	return currentTick-initialTick
end

return timerClass
