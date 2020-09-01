local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local function CreateBindable(Name)
	if Name then
		local BindableEvent = Instance.new("BindableEvent")
		BindableEvent.Name = Name
		return BindableEvent
	end
end


local Queue = {}
Queue.__index = Queue

function Queue.new(...)
	local self = {}
	
	self.Destroyed = false
	self.Started = false
	self.Finished = false
	self.Full = false
	self.Players = {}
	
	local Params = {...}
	self.MaxPlayers = Params[1] or 5
	self.MinPlayers = Params[2] or 5
	self.QueueTime = Params[3] or 15
	self.PlaceId = Params[4] or self.PlaceId
	
	self.Bindables = {}
	for _,EventName in pairs({"PlayerAdded", "PlayerRemoved", "QueueStarted", "QueueEnded", "QueueTick"}) do
		local Bindable = CreateBindable(EventName)
		self.Bindables[EventName] = Bindable
		self[EventName] = Bindable.Event
	end
	
	self.LeaveConnection = game:GetService("Players").PlayerRemoving:Connect(function(Player)
		self:RemovePlayer(Player)
	end)
	
	return setmetatable(self, Queue)
end

function Queue:AddPlayer(Player)
	if self.Destroyed then warn("Queue is destroyed.") return end;
	assert(Player.ClassName == "Player", "Expected type 'Player', got " .. tostring(Player and Player.ClassName))
	if self.Full then return end;
	if table.find(self.Players, Player) then warn("Attempt to 'AddPlayer', but player already queued.") return end;
	table.insert(self.Players, Player)
	self.Bindables.PlayerAdded:Fire(Player)
	self:Check()
end

function Queue:RemovePlayer(Player)
	if self.Destroyed then warn("Queue is destroyed.") return end;
	assert(Player.ClassName == "Player", "Expected type 'Player', got " .. tostring(Player and Player.ClassName))
	local TableIndex = table.find(self.Players, Player)
	if not TableIndex then warn("Attempt to 'RemovePlayer', but player is nil.") return end;
	table.remove(self.Players, TableIndex)
	self.Bindables.PlayerRemoved:Fire(Player)
	self:Check()
end

function Queue:GetPlayers()
	return Queue.Players
end

function Queue:Start()
	if not self.CheckRunning then
		self.CheckRunning = true
		self:Check()
	end
end

function Queue:Check()
	if self.Destroyed then warn("Queue is destroyed.") return end;
	if #self.Players >= self.MinPlayers and #self.Players <= self.MaxPlayers then
		self.Full = true
		if self.Started or not self.CheckRunning and not self.Finished then return end;
		self.Started = true
		print("Queue Full - Match Starting")
		
		local StartTime = os.time()
		local QueueTime = self.QueueTime
		while self.Started and QueueTime > 0 and not self.Destroyed do
			local CurrentTime = os.time()
			if CurrentTime - StartTime >= 1 then
				StartTime = CurrentTime
				QueueTime -= 1
				self.Bindables.QueueTick:Fire(QueueTime)
			end
			if QueueTime == 0 then
				self.Finished = true
			end
			RunService.Stepped:Wait()
		end
		
		if self.Finished then
			self:Destroy()
			print("QUEUE WAITED - TELEPORTING NOW")
			for _,Player in pairs(self.Players) do
				print(Player.Name)
			end
			
			local Success, ServerAccessCode = pcall(TeleportService.ReserveServer,TeleportService,self.PlaceId)
			if Success then
				TeleportService:TeleportToPrivateServer(self.PlaceId, ServerAccessCode, self.Players)
			end
			return
		else
			warn("Queue Cancelled")
			self.Started = false
		end
	else
		self.Full = false
	end
	self.Started = false
end

function Queue:Destroy()
	if self.Destroyed then return end;
	self.Destroyed = true
	self.LeaveConnection = nil
	for _,Bindable in pairs(self.Bindables) do
		Bindable:Destroy()
	end
end


return Queue
