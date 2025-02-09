AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( 'shared.lua' )

local DCDockType = list.Get( "SBEP_DockingClampModels" )
local DD = list.Get( "SBEP_DoorControllerModels" )

function Bezier4(P0, P1, P2, P3, Step)
	return P0 * ( 1 - Step ) ^ 3 + 3 * P1 * Step * ( 1 - Step ) ^ 2 + 3 * P2 * Step ^ 2 * ( 1 - Step ) + Step ^ 3 * P3
end
local succ = Sound("sb/clamp_succ.wav")
hook.Add("SetupMove", "TeleportBetweenClamps", function(ply, mv, cmd)
	if IsValid(ply) and ply["TravellingBetweenClamps"] then
		if ply:GetMoveType() != MOVETYPE_FLY then
			ply["ClampOldMoveType"] = ply:GetMoveType()
		end
		ply:SetMoveType(MOVETYPE_FLY)
		if IsValid(ply["StartClamp"]) and IsValid(ply["EndClamp"]) then
			local offset = (ply:EyePos() - mv:GetOrigin()) / 2
			local subt = ply["ClampInvert"]
			local dir = (ply["EndClamp"]:CalcCenterPos() - ply["StartClamp"]:CalcCenterPos()):GetNormalized()
			local LinkLock = ply["EndClamp"]
			local ang = dir:Angle()
			local clipdir = ply["StartClamp"]:CalcForward()
			local clipdir2 = -ply["EndClamp"]:CalcForward()
			local cplength = (ply["StartClamp"]:GetPos() + (ply["StartClamp"].ModelSize * clipdir)):Distance( ply["EndClamp"]:GetPos())
			local startent = ply["StartClamp"]
			local endent = ply["EndClamp"]
			local start = ply["StartClamp"]:CalcCenterPos() - clipdir * 47
			local start2 = ply["StartClamp"]:CalcCenterPos() + clipdir * cplength
			local endpos = ply["EndClamp"]:CalcCenterPos()
			local endpos2 = ply["EndClamp"]:CalcCenterPos() - clipdir2 * cplength
			if subt then
				mv:SetOrigin(Bezier4(start, start2, endpos2, endpos, 1 - (CurTime() - ply["ClampStartTime"])) - offset)
				local dir = (Bezier4(start, start2, endpos2, endpos, 1 - (CurTime() - ply["ClampStartTime"])) - Bezier4(start, start2, endpos2, endpos, 1 - (CurTime() - ply["ClampStartTime"]) + 0.17))
				mv:SetVelocity(dir)
				else
				mv:SetOrigin(Bezier4(start, start2, endpos2, endpos, (CurTime() - ply["ClampStartTime"])) - offset)
				local dir = (Bezier4(start, start2, endpos2, endpos, (CurTime() - ply["ClampStartTime"])) - Bezier4(start, start2, endpos2, endpos, (CurTime() - ply["ClampStartTime"]) - 0.17))
				mv:SetVelocity(dir)
			end	
			if CurTime() - ply["ClampStartTime"] > 1 then
				ply["TravellingBetweenClamps"] = false
				ply["StartClamp"] = nil
				ply["EndClamp"] = nil
				ply["ClampInvert"] = nil
				ply:SetMoveType(ply["ClampOldMoveType"])
			end
			else
			ply["TravellingBetweenClamps"] = false
			ply["StartClamp"] = nil
			ply["EndClamp"] = nil
			ply["ClampInvert"] = nil
			ply:SetMoveType(ply["ClampOldMoveType"] or MOVETYPE_WALK)
		end
	end
end)
function ENT:Initialize()
	self.Entity:PhysicsInit( SOLID_VPHYSICS )
	self.Entity:SetMoveType( MOVETYPE_VPHYSICS )
	self.Entity:SetSolid( SOLID_VPHYSICS )
	self.Entity:SetUseType( SIMPLE_USE )
	self.Inputs = Wire_CreateInputs( self.Entity, { "Dock", "UndockDelay", "ClampOverride [ENTITY]" } )
	self.Outputs = Wire_CreateOutputs( self.Entity, { "Status" })
	self:SetDockMode( self.DockMode )
	local phys = self.Entity:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
		phys:EnableGravity(false)
		phys:EnableDrag(true)
		phys:EnableCollisions(true)
	end
	self.PhysObj = self.Entity:GetPhysicsObject()
	self.LinkLock = nil
	self.UDD = false
	self.Usable = true
	self:GetEFPoints()
	self:CalcCenterPos()
	self.ModelSize = self:FindModelSize()
	
	if SC then
		self.PrevCurTime = CurTime()
	end
end

function ENT:TriggerInput(iname, value)		
	if (iname == "Dock") then
		if (value > 0) and self.DockMode <= 2 then
			self.DockMode = 2
			self.Entity:EmitSound("Buttons.snd1")
			elseif value <= 0 and self.DockMode ~= 0 and self.DockMode ~= 1 then
			self.Entity:EmitSound("Buttons.snd19")
			if self.UDD then
				self.DockMode = 0
				self.DockTime = CurTime() + 2
				else
				self.DockMode = 1
				self:Disengage()
			end			
		end
		elseif (iname == "UndockDelay") then
		if (value > 0) then
			self.UDD = true
			else
			self.UDD = false
		end
	end
end

function ENT:AddDockDoor()
	local Data = DD[ string.lower( self.Entity:GetModel() ) ]
	if !Data then return end
	
	self.Doors = self.Doors or {}
	for n,Door in ipairs( Data ) do
		local D = ents.Create( "sbep_base_door" )
		D:Spawn()
		D:Initialize()
		if CPPI and self.CPPISetOwner then D:CPPISetOwner( self:CPPIGetOwner() ) end
		local ct = D:SetDoorType( Door.type )
		D:Attach( self.Entity , Door.V , Door.A )
		table.insert( self.Doors , D )
	end
end

function ENT:SetDockType( strType )
	if !strType then return false end
	local DockType = DCDockType[ string.lower( self.Entity:GetModel() ) ]
	if !DockType then return false end
	
	self.ALType  = strType
	self.Entity:SetName( strType )
	self.CompatibleLocks = DockType.Compatible
end
local directions = {
	["Forward"] = Angle(0,0,0),
	["Back"] = Angle(180,0,0),
	["Left"] = Angle(0,-90,0),
	["Right"] = Angle(0,90,0),
	["Up"] = Angle(90,0,0),
	["Down"] = Angle(-90,0,0)
}
function ENT:Think()
	self.Model = self:GetTubeModel()
	if self.Direction then
		self:SetDir(directions[self.Direction])
	end
	if self.Doors then
		if self.DockMode == 4 then
			for m,n in ipairs( self.Doors ) do
				n.OpenTrigger = true
			end
			else
			for m,n in ipairs( self.Doors ) do
				n.OpenTrigger = false
			end
		end
	end
	if self.DockMode == 0 then
		if self.DockTime > CurTime() then
			self:Disengage()
			self.DockMode = 1
		end
	end
	self.ConstraintDelay = self.ConstraintDelay or CurTime()
	if CurTime() > self.ConstraintDelay then
		self.ConstraintTable = self.ConstraintTable or {}
		self.ConstraintTable = constraint.GetAllConstrainedEntities(self)
		self.ConstraintDelay = CurTime() + 5
	end
	if self.DockMode == 2 then
		if !IsValid(self.Inputs.ClampOverride.Value) then
			local T = ents.FindInSphere(self:CalcCenterPos(), self.ScanDist)
			local closest
			local rem = {}
			for k,v in pairs(T) do
				if v.IsAirLock then
					for i,j in pairs(self.ConstraintTable) do
						if j == v then table.insert(rem, j) end
					end
				end
			end
			for k,v in pairs(rem) do
				table.RemoveByValue(T, v)
			end
			for _,i in pairs( T ) do
				if( IsValid(i) and i ~= self and i.IsAirLock and i.DockMode == 2 and !IsValid(i.Inputs.ClampOverride.Value)) then
					if !(table.HasValue(self.ConstraintTable, i) or (IsValid(self:GetParent()) and self:GetParent() == i:GetParent())) then
						closest = closest or i
						if self:GetPos():DistToSqr(i:GetPos()) <= self:GetPos():DistToSqr(closest:GetPos()) then
							closest = i
						end
					end
				end
			end
			if IsValid(closest) then
				self:BeginDock(closest)
			end
			elseif !IsValid(self.Inputs.ClampOverride.Value.LinkLock) and self.Inputs.ClampOverride.Value.DockMode == 2 then
			self:BeginDock(self.Inputs.ClampOverride.Value)
		end
	end
	
	if self.DockMode == 3 and IsValid(self.LinkLock) then
		if self:WorldSpaceCenter():DistToSqr(self.LinkLock:WorldSpaceCenter()) <= math.max(self.MDist, self.LinkLock.MDist) then
			self.DockMode = 4
			self.LinkLock.DockMode = 4
			self.Entity:EmitSound("Building_Teleporter.Ready")
		end
	end
	
	if self.DockMode == 4 and IsValid(self.LinkLock) then
		local cmins = Vector(-16.000000, -16.000000, 0.000000)
		local cmaxs = Vector(16.000000, 16.000000, 72.000000)
		local tr = util.TraceHull({
			start = self:CalcCenterPos() - Vector(0,0,cmaxs.z),
			endpos = self:CalcCenterPos() - Vector(0,0,cmaxs.z),
			mins=cmins * 2,
			maxs=cmaxs * 2,
			ignoreworld = true,
			filter=function(ent) if ent:IsPlayer() then return true else return false end end
		})
		if tr.Hit and !tr.Entity["TravellingBetweenClamps"] and tr.Entity:GetAimVector():Dot(self:CalcForward()) > 0.4 then
			tr.Entity["TravellingBetweenClamps"] = true
			tr.Entity["StartClamp"] = self
			tr.Entity["EndClamp"] = self.LinkLock
			tr.Entity["ClampStartTime"] = CurTime()
			if tr.Entity["StartClamp"]:EntIndex() > tr.Entity["EndClamp"]:EntIndex() then
				tr.Entity["StartClamp"] = self.LinkLock
				tr.Entity["EndClamp"] = self
				tr.Entity["ClampInvert"] = 1
			end
			tr.Entity:EmitSound(succ)
		end
	end
	if self.DockMode == 4 and IsValid(self.LinkLock) and self:WorldSpaceCenter():DistToSqr(self.LinkLock:WorldSpaceCenter()) > math.max(self.MDist, self.LinkLock.MDist) then
		self.DockMode = 2
		self:Disengage()
	end
	if self.LinkLock and !self.LinkLock:IsValid() then
		self.DockMode = 2
		self:Disengage()
	end
	Wire_TriggerOutput( self.Entity, "Status", self.DockMode )
	if self.ClDockMode ~= self.DockMode then
		self:SetDockMode( self.DockMode )
		self.ClDockMode = self.DockMode
	end
	self:SetDockMode(self.DockMode)
	if SC then
		self.TimeDelta = CurTime()-self.PrevCurTime
		self.PrevCurTime = CurTime()
		self:BalanceShields()
		self:BalanceCap()
		if IsValid(self.SC_CoreEnt) then
			local sigrad = (self.SC_CoreEnt:GetSigRad() * 52.49)
			self.MDist = math.max((sigrad * sigrad), 2000000)
			self.ScanDist = sigrad
			else
			self.MDist = 2000000
			self.ScanDist = 2000
		end
	end
	self:SetMDist(self.MDist)
	self:NextThink(CurTime())
	return true
end
function ENT:BalanceShields()
	if IsValid(self.SC_CoreEnt) and IsValid(self.LinkLock) and IsValid(self.LinkLock.SC_CoreEnt) then
		if self.SC_CoreEnt:GetShieldAmount() < self.SC_CoreEnt:GetShieldMax() then
			if self.LinkLock.SC_CoreEnt:GetShieldAmount() > self.SC_CoreEnt:GetShieldAmount() then
				--fill in 10 seconds
				Flowrate = math.min(self.SC_CoreEnt:GetShieldMax(), self.LinkLock.SC_CoreEnt:GetShieldMax()) / (10/self.TimeDelta)
				self.SC_CoreEnt:SetShieldAmount(self.SC_CoreEnt:GetShieldAmount() + math.Clamp(self.SC_CoreEnt:GetShieldMax() - self.SC_CoreEnt:GetShieldAmount(), 1, Flowrate))
				self.LinkLock.SC_CoreEnt:SetShieldAmount(self.LinkLock.SC_CoreEnt:GetShieldAmount() - math.Clamp(self.SC_CoreEnt:GetShieldMax() - self.SC_CoreEnt:GetShieldAmount(), 1, Flowrate))
			end
		end
		
	end
end
function ENT:BalanceCap()
	if IsValid(self.SC_CoreEnt) and IsValid(self.LinkLock) and IsValid(self.LinkLock.SC_CoreEnt) then
		if self.SC_CoreEnt:GetAmount("Energy") < self.SC_CoreEnt:GetMaxAmount("Energy") then
			if self.LinkLock.SC_CoreEnt:GetAmount("Energy") > self.SC_CoreEnt:GetAmount("Energy") then
				--fill in 8 seconds
				Flowrate = math.min(self.SC_CoreEnt:GetMaxAmount("Energy"), self.LinkLock.SC_CoreEnt:GetMaxAmount("Energy")) / (8/self.TimeDelta)
				self.SC_CoreEnt:SetAmount("Energy", self.SC_CoreEnt:GetAmount("Energy") + math.Clamp(self.SC_CoreEnt:GetMaxAmount("Energy") - self.SC_CoreEnt:GetAmount("Energy"), 1, Flowrate))
				self.LinkLock.SC_CoreEnt:SetAmount("Energy", self.LinkLock.SC_CoreEnt:GetAmount("Energy") - math.Clamp(self.SC_CoreEnt:GetMaxAmount("Energy")  - self.SC_CoreEnt:GetAmount("Energy"), 1, Flowrate))
			end
		end
	end
end
function ENT:BeginDock(DockTo)
	local TypeMatch = true
	self.LinkLock = DockTo
	DockTo.LinkLock = self.Entity
	self.Entity:SetLinkLock( self.LinkLock )
	self.LinkLock:SetLinkLock( self.Entity )
	self.DockMode = 3
	DockTo.DockMode = 3
	self.Entity:EmitSound("Building_Teleporter.Send")
end

function ENT:PhysicsCollide( data, physobj )
	
end

function ENT:OnTakeDamage( dmginfo )
	
end

function ENT:Touch( ent )
	
end

function ENT:OnRemove()
	
end

function ENT:Use( activator, caller )
	if self.Usable then
		if (self.DockMode < 2) then
			self.DockMode = 2		
			self.Entity:EmitSound("Buttons.snd1")
			else
			self.Entity:EmitSound("Buttons.snd19")
			if self.UDD then
				self.DockMode = 0
				self.DockTime = CurTime() + 2		
				else
				self.DockMode = 1
				self:Disengage()
			end
		end
	end
end

function ENT:PreEntityCopy()
	local DI = {}
	
	DI.Type 	= self.ALType
	DI.Usable 	= self.Usable
	
	DI.EfPoints = {}
	for i = 1,10 do
		local Vec = self.Entity:GetNetworkedVector("EfVec"..i)
		if Vec and Vec ~= Vector(0,0,0) then
			DI.EfPoints[i] = {}
			DI.EfPoints[i].x = Vec.x
			DI.EfPoints[i].y = Vec.y
			DI.EfPoints[i].z = Vec.z
			DI.EfPoints[i].sp = self.Entity:GetNetworkedInt("EfSp"..i) or 0
		end
	end
	
	DI.Doors = {}
	if self.Doors then
		for n,D in ipairs( self.Doors ) do
			if D and D:IsValid() then
				DI.Doors[n] = D:EntIndex()
			end
		end
	end
	
	
	if WireAddon then
		DI.WireData = WireLib.BuildDupeInfo( self.Entity )
	end
	
	DI.CompatibleLocks = self.CompatibleLocks
	DI.DockMode = self.DockMode
	if self.LinkLock and self.LinkLock:IsValid() then
		DI.LinkLock = self.LinkLock:EntIndex()
	end
	
	duplicator.StoreEntityModifier(self, "SBEPDCI", DI)
end
duplicator.RegisterEntityModifier( "SBEPDCI" , function() end)

function ENT:PostEntityPaste(pl, Ent, CreatedEntities)
	
	local DI = Ent.EntityMods.SBEPDCI
	
	if !DI then return end
	
	self:SetDockType( DI.Type )
	self.Usable = DI.Usable
	
	for k,v in ipairs( DI.EfPoints ) do
		self.Entity:SetNetworkedVector("EfVec"..k, Vector( v.x , v.y , v.z ) )
		self.Entity:SetNetworkedInt("EfSp"..k, v.sp)
	end
	
	self.Doors = {}
	for n,I in ipairs( DI.Doors ) do
		self.Doors[n] = CreatedEntities[I]
	end
	
	self.CompatibleLocks = DI.CompatibleLocks
	self.DockMode = DI.DockMode
	if DI.LinkLock then
		self.LinkLock = CreatedEntities[ DI.LinkLock ]
	end
	
	
	if DI.WireData then
		WireLib.ApplyDupeInfo( pl, Ent, DI.WireData, function(id) return CreatedEntities[id] end)
	end
	
end

function ENT:Disengage()
	if self.LinkLock and self.LinkLock:IsValid() then
		if self.LinkLock.DockMode == 3 or self.LinkLock.DockMode == 4 then
			self.LinkLock.DockMode = 2
			self.LinkLock:SetDockMode(2)
		end
		self.LinkLock.LinkLock = nil
		self.LinkLock:SetLinkLock( nil )
		self:SetLinkLock( nil )
	end
	self.LinkLock = nil
end