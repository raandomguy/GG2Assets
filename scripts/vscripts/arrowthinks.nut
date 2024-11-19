local target = null
const DISTANCECHECK = 200
const SELFHITDISTANCECHECK = 250
const FRAMETIMEDISTANCE = 0.09 //6 * 0.015, since arrows fly at 36 hu/frame
local owner = self.GetOwner()
self.GetScriptScope().isAllowedToTeleport <- true

function findTargetThink() {
	local player = null
	local finalTarget = null
	local dist = 600
	while(player = Entities.FindByClassnameWithin(player, "player", self.GetOrigin(), 600)) {
		if(player.GetTeam() != TF_TEAM_BLUE) continue
		if((player.GetCenter() - self.GetOrigin()).Length() > dist) continue

		local traceTable = {
			start = self.GetOrigin()
			end = player.GetCenter()
			mask = MASK_SHOT
			ignore = self
		}

		TraceLineEx(traceTable)
		if(traceTable.hit && traceTable.enthit == player) {
			finalTarget = player
			dist = (player.GetCenter() - self.GetOrigin()).Length()
		}
	}

	if(finalTarget) { //player in los
		target = finalTarget
		AddThinkToEnt(self, "haveTargetThink")
	}
	return -1
}

function haveTargetThink() {
	if(NetProps.GetPropInt(target, "m_lifeState") != 0) { //target died before reached
		target = null
		AddThinkToEnt(self, "findTargetThink")
		return
	}

	local oldOrigin = self.GetOrigin()
	local forward = self.GetAbsAngles().Forward()
	local adjustedOrigin = oldOrigin + forward * 16

	local worldTrace = {
		start = adjustedOrigin
		end = adjustedOrigin + self.GetAbsVelocity() * FRAMETIMEDISTANCE
		mask = MASK_SHOT
		ignore = self
	}
	TraceLineEx(worldTrace)
	
	if(!worldTrace.hit) {
		return -1
	}
	if(!isAllowedToTeleport) { //if we hit something, don't teleport
		AddThinkToEnt(self, "emptyThink")
		return
	}

	local ent = worldTrace.enthit
	local botCenter = target.GetCenter()
	local forwardVector = forward * DISTANCECHECK
	local newOrigin = botCenter - Vector(forwardVector.x, forwardVector.y, 0)
	local newAngles = QAngle(0, self.GetAbsAngles().y, self.GetAbsAngles().z)

	if(ent.GetClassname() != "player" && ent.GetClassname() != "func_physbox_multiplayer") { //arrow about to collide with something
		local validLocation = false
		local degreeX = 0
		local degreeY = 0
		
		local fractionModifier = worldTrace.fraction - 0.05 > 0 ? worldTrace.fraction - 0.05 : worldTrace.fraction
		local particle1 = SpawnEntityFromTable("info_particle_system", {
			effect_name = "magic_crossbow_wheel"
			start_active = true
			angles = self.GetAbsAngles() + QAngle(90, 0, 0)
			origin = adjustedOrigin + self.GetAbsVelocity() * FRAMETIMEDISTANCE * fractionModifier //try to avoid clipping into walls
		})
		
		while(!validLocation) {
			local targetTrace = {
				start = botCenter
				end = newOrigin
				mask = MASK_SHOT
				ignore = target
			}
			TraceLineEx(targetTrace)

			if(targetTrace.hit) { //potential area to teleport to is occupied
				local xPos = DISTANCECHECK * cos(degreeX) + botCenter.x
				local yPos = DISTANCECHECK * sin(degreeY) + botCenter.y

				newOrigin = Vector(xPos, yPos, botCenter.z)
				local distance = botCenter - newOrigin
				distance.Norm()
				newAngles = VectorAngles(distance)
				degreeX += 20
				degreeY += 20

				if(degreeX == 360) { //this is needed lol
					newOrigin = target.GetCenter()
					validLocation = true
				}
			}
			else {
				validLocation = true
			}
		}
		
		local particle2 = SpawnEntityFromTable("info_particle_system", {
			effect_name = "magic_crossbow_wheel"
			start_active = true
			angles = newAngles + QAngle(90, 0, 0)
			origin = newOrigin
		})
		
		self.Teleport(true, newOrigin, true, newAngles, true, newAngles.Forward() * 2400)
		AddThinkToEnt(self, "emptyThink")
		
		EntFireByHandle(particle1, "Kill", null, 4, null, null)
		EntFireByHandle(particle2, "Kill", null, 4, null, null)
	}
}

function hitSelf() {
	local ownerCenter = owner.GetCenter()
	
	local preTrace = {
		start = self.GetOrigin()
		end = self.GetOrigin() + self.GetAbsVelocity() * 0.105 //about 250 hu
		mask = MASK_SHOT
		ignore = owner
	}
	TraceLineEx(preTrace)
	
	if(!preTrace.hit && (self.GetOrigin() - ownerCenter).Length() < SELFHITDISTANCECHECK) {
		return -1
	}
	
	local eyeAngles = owner.EyeAngles().Forward()
	local origin = self.GetOrigin()

	local newOrigin = Vector(eyeAngles.x, eyeAngles.y, ownerCenter.z) + Vector(origin.x, origin.y, 0)
	local predictedOrigin = ownerCenter + owner.GetAbsVelocity().Scale((ownerCenter - newOrigin).Length() / 4800)
	
	local dist = predictedOrigin - newOrigin
	dist.Norm()
	local newAngles = VectorAngles(dist)

	local validLocation = false
	local degreeX = 0
	local degreeY = 0
	
	local particle1 = SpawnEntityFromTable("info_particle_system", {
		effect_name = "magic_crossbow_wheel"
		start_active = true
		angles = self.GetAbsAngles() + QAngle(90, 0, 0)
		origin = self.GetOrigin()
	})
	
	while(!validLocation) {
		local targetTrace = {
			start = ownerCenter
			end = newOrigin
			mask = MASK_SHOT
			ignore = owner
		}
		TraceLineEx(targetTrace)
		DebugDrawLine(ownerCenter, newOrigin, 255, 0, 0, true, 2.5)

		if(targetTrace.hit) { //potential area to teleport to is occupied
			local xPos = DISTANCECHECK * cos(degreeX) + ownerCenter.x
			local yPos = DISTANCECHECK * sin(degreeY) + ownerCenter.y

			newOrigin = Vector(xPos, yPos, ownerCenter.z)
			predictedOrigin = ownerCenter + owner.GetAbsVelocity().Scale((ownerCenter - newOrigin).Length() / 4800)
			//DebugDrawLine(predictedOrigin, newOrigin, 255, 0, 0, true, 2.5)
			dist = predictedOrigin - newOrigin
			dist.Norm()
			newAngles = VectorAngles(dist)
			
			degreeX += 20
			degreeY += 20

			if(degreeX == 360) { //figure out what to do for self hit
				//newOrigin = target.GetCenter()
				validLocation = true
			}
		}
		else {
			validLocation = true
		}
	}
	
	local particle2 = SpawnEntityFromTable("info_particle_system", {
		effect_name = "magic_crossbow_wheel"
		start_active = true
		angles = newAngles + QAngle(90, 0, 0)
		origin = newOrigin
	})
	
	self.Teleport(true, newOrigin, true, newAngles, true, newAngles.Forward() * 4800)
	self.SetTeam(TF_TEAM_BLUE)
	self.SetOwner(null)
	NetProps.SetPropInt(self, "m_iDeflected", 1)
	NetProps.SetPropBool(self, "m_bCritical", false)
	
	EntFireByHandle(particle1, "Kill", null, 4, null, null)
	EntFireByHandle(particle2, "Kill", null, 4, null, null)
	
	AddThinkToEnt(self, "emptyThink")
}

function emptyThink() { //this is to prevent the main crossbow think from assigning it another think
	return 100
}

//from samisalreadytaken vs_math
const RAD2DEG = 57.295779513;
const DEG2RAD = 0.017453293;

//converts vector to qangle
function VectorAngles(forward)
{
	local yaw = 0.0, pitch = yaw;

	if ( !forward.y && !forward.x )
	{
		if ( forward.z > 0.0 )
			pitch = 270.0;
		else
			pitch = 90.0;
	}
	else
	{
		yaw = atan2( forward.y, forward.x ) * RAD2DEG;
		if ( yaw < 0.0 )
			yaw += 360.0;

		pitch = atan2( -forward.z, forward.Length2D() ) * RAD2DEG;
		if ( pitch < 0.0 )
			pitch += 360.0;
	};

	return QAngle(pitch, yaw, 0.0);
}