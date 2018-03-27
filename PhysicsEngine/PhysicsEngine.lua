--General Parameters that get set later in the script (all can be configured in the actual rainmeter ini)
GraphicsUpdateRate = 1 -- how often the meters position gets updated by the lua
PhysicsUpdateRate = 0.0166666667 -- The time interval used in physics calculations
ScreenWidth=0
ScreenHeight = 0
InternalTickTimer=0
function getDistance(x,y)
	return math.sqrt(x*x+y*y)
end
function getDotProduct(x1,y1,x2,y2)
	return x1*x2+y1*y2
end
function normalize(X,Y)
	local number = getDistance(X,Y)
	return {x=X/number,y=Y/number}
end
--Physics Engine Section, handles interactions between meters and stuff
PhysicsEngine={
	physicsMeters = {},
	draggedMeter="",
	MouseX=0,
	MouseY=0,
	MouseXVel=0,
	MouseYVel=0
}
function PhysicsEngine:physicsTick()
	for k,v in pairs(self.physicsMeters) do
		v:tick()
	end
	self:doCollisions(self:findCollisions())
end
function PhysicsEngine:findCollisions()
	local output = {}
	for k,v in pairs(self.physicsMeters) do
		for j,h in pairs(self.physicsMeters) do
			if not (j==k) then
				if (output[k..j]==nil) and (output[j..k]==nil) then
					local deltaX = (h.XPos)-(v.XPos)
					local deltaY = (h.YPos)-(v.YPos)
					local dist = getDistance(deltaX,deltaY)
					if dist<(v.Radius+h.Radius) then
					
						output[k..j] = {v,h}
					end
				end
			end
		end
	end
	return output
end
--Simple elastic collision between balls, might optimize the detection system once the simulation gets more complex
function PhysicsEngine:doCollisions(collisions)
	local printer = ""
	for r,t in pairs (collisions) do
		printer = printer.." "..r
		local v = t[1]
		local h=t[2]
		local deltaX = (h.XPos)-(v.XPos)
		local deltaY = (h.YPos)-(v.YPos)
		local dist = getDistance(deltaX,deltaY)
		
					
		local goodDist = (v.Radius+h.Radius)
					--local norm = normalize(-deltaX,-deltaY)
					
					
					--h.XPos = h.XPos+goodDist*norm.x*1.5
					--h.YPos = h.YPos+goodDist*norm.y*1.5
		v.XVel = v.XVel - ((2*h.Radius/goodDist)*(getDotProduct(v.XVel-h.XVel,v.YVel-h.YVel,-deltaX,-deltaY)/(dist*dist))*-deltaX)*2
		v.YVel = v.YVel - ((2*h.Radius/goodDist)*(getDotProduct(v.XVel-h.XVel,v.YVel-h.YVel,-deltaX,-deltaY)/(dist*dist))*-deltaY)*2
		h.XVel = h.XVel - ((2*v.Radius/goodDist)*(getDotProduct(-v.XVel+h.XVel,-v.YVel+h.YVel,deltaX,deltaY)/(dist*dist))*deltaX)*2
		h.YVel = h.YVel - ((2*v.Radius/goodDist)*(getDotProduct(-v.XVel+h.XVel,-v.YVel+h.YVel,deltaX,deltaY)/(dist*dist))*deltaY)*2
		
	end
	print(printer)
end
function PhysicsEngine:setMousePos(x,y)
	print("Help")
	local multiplier = 1/(GraphicsUpdateRate)
	if not multiplier == 0 then
		self.MouseXVel=(x-self.MouseX)*multiplier
		self.MouseYVel=(x-self.MouseX)*multiplier
		
	end
	
	self.MouseX = x
	self.MouseY = y
	InternalTickTimer=0
	if not draggedMeter == "" then
		local temp = self:getOrRegisterPhysicsMeter(draggedMeter)
		temp.XPos = x
		temp.YPos = y
	end
end
function PhysicsEngine:graphicsTick()
	for k,v in pairs(self.physicsMeters) do
		local meter = SKIN:GetMeter(k)
		meter:SetX(v.XPos)
		meter:SetY(v.YPos)
	end
end
function PhysicsEngine:registerSphericalMeter(metername,radius)
	local meter = SKIN:GetMeter(metername)
	local newphysicsmeter = PhysicalMeter:new{Name=metername,XPos=meter:GetX(),YPos=meter:GetY(),Radius=radius}
	self.physicsMeters[metername] = newphysicsmeter
end
function PhysicsEngine:registerMeter(metername)
	local meter = SKIN:GetMeter(metername)
	local newphysicsmeter = PhysicalMeter:new{Name=metername,XPos=meter:GetX(),YPos=meter:GetY()}
	self.physicsMeters[metername] = newphysicsmeter
end
function PhysicsEngine:getOrRegisterPhysicsMeter(metername,radius)
	if self.physicsMeters[metername]==nil then
		self:registerSphericalMeter(metername,radius)
	end
	return self.physicsMeters[metername]
end
function PhysicsEngine:onLeftDown(metername,x,y,radius)
	local temp = self:getOrRegisterPhysicsMeter(metername,radius)
	draggedMeter=temp.Name
end
function PhysicsEngine:onLeftUp(metername,x,y,radius)
	local temp = self:getOrRegisterPhysicsMeter(metername,radius)
	if not draggedMeter == "" then
		temp.XVel = self.MouseXVel
		temp.YVel = self.MouseYVel
	end
	temp.XVel = 100
	temp.YVel = -100
	draggedMeter=""
end
Gravity = 0
--PhysicalMeter section, for meter physics
PhysicalMeter = {
	Name="",
	XPos=0,
	YPos=0,
	XVel=0,
	YVel=0,
	Radius=10,
	XAccel=0,
	YAccel=0,
	Bounciness=.5,
	Drag=0,
	BeingDragged = 0
}
function PhysicalMeter:new(obj)
	obj = obj or {}
	self.__index = self
	setmetatable(obj,self)
	return obj	
end
function PhysicalMeter:tick()
	-- simple physics, may upgrade later
	self.XPos=self.XPos+self.XVel*PhysicsUpdateRate+0.5*self.XAccel*PhysicsUpdateRate*PhysicsUpdateRate
	self.YPos=self.YPos+self.YVel*PhysicsUpdateRate+0.5*self.YAccel*PhysicsUpdateRate*PhysicsUpdateRate
	self.XVel=self.XVel+PhysicsUpdateRate*self.XAccel-self.XVel*PhysicsUpdateRate*self.Drag
	self.YVel=self.YVel+PhysicsUpdateRate*(self.YAccel+Gravity)-self.YVel*PhysicsUpdateRate*self.Drag
	if(self.Radius>0) then
		self:doScreenCollisions()
	end
end
function PhysicalMeter:doScreenCollisions()
	if self.XPos>(ScreenWidth-self.Radius) then
		self.XPos=ScreenWidth-self.Radius
		self.XVel=-self.XVel*self.Bounciness
	elseif self.XPos<(self.Radius) then
		self.XPos=self.Radius
		self.XVel=-self.XVel*self.Bounciness
	end
	if self.YPos>(ScreenHeight-self.Radius) then
		self.YPos=ScreenHeight-self.Radius
		self.YVel=-self.YVel*self.Bounciness
	elseif self.YPos<(self.Radius) then
		self.YPos=self.Radius
		self.YVel=-self.YVel*self.Bounciness
	end
end
-- functions that rainmeter uses
function Initialize()
	GraphicsUpdateRate = SELF:GetNumberOption("GraphicsUpdateRate")/1000
	PhysicsUpdateRate = SELF:GetNumberOption("PhysicsUpdateRate")/1000
	ScreenWidth = SELF:GetNumberOption("ScreenWidth")
	ScreenHeight = SELF:GetNumberOption("ScreenHeight")
	
end
function Update()
	InternalTickTimer=InternalTickTimer+1
	for i=1,GraphicsUpdateRate/PhysicsUpdateRate do
		PhysicsEngine:physicsTick()
	end
	
	PhysicsEngine:graphicsTick()
end

