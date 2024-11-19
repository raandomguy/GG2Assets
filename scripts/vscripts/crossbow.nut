local scope = self.GetScriptScope()
scope.crossbow <- null;
scope.counter <- 0;
scope.INTERVAL <- 1;
scope.SELFHITDISTANCECHECK <- 250;
scope.hasPenetration <- false
scope.itemDefIndex <- 305
scope.hasFiredReplacement <- false
scope.dmgBonus <- 0
scope.viewmodel <- NetProps.GetPropEntity(self, "m_hViewModel")

if(!("secondaryxbow" in getroottable()) || !secondaryxbow.IsValid()) {
	::secondaryxbow <- Entities.CreateByClassname("tf_weapon_crossbow")
	NetProps.SetPropInt(secondaryxbow, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", 305)
	NetProps.SetPropBool(secondaryxbow, "m_AttributeManager.m_Item.m_bInitialized", true)
	secondaryxbow.DispatchSpawn()
	secondaryxbow.SetClip1(-1)
}

if(!("crossbowParticle" in getroottable()) || !crossbowParticle.IsValid()) {
	PrecacheEntityFromTable({classname = "info_particle_system", effect_name = "magic_crossbow_wheel"})
	PrecacheEntityFromTable({classname = "info_particle_system", effect_name = "unusual_magicsmoke_blue_glow"})

	::crossbowParticle <- SpawnEntityFromTable("trigger_particle", {
		particle_name = "unusual_magicsmoke_blue_glow"
		attachment_type = 4
		attachment_name = "vm_weapon_bone_2"
		spawnflags = 64
	})
}

if(!("arrowdeath" in getroottable())) { //this is for all instances of the upgrade
	PrecacheEntityFromTable({classname = "info_particle_system", effect_name = "utaunt_hands_teamcolor_blue"})
	PrecacheEntityFromTable({classname = "info_particle_system", effect_name = "utaunt_tarotcard_blue_glow"})

	::arrowdeath <- {
		OnScriptHook_OnTakeDamage = function(params) {
			if(params.attacker == null || IsPlayerABot(params.attacker)) return
			if(params.inflictor == null || params.inflictor.GetClassname() != "tf_projectile_healing_bolt") return
			local syringe = params.inflictor
			local bot = params.const_entity
			local crossbow = NetProps.GetPropEntity(syringe, "m_hLauncher")
			if(crossbow.GetAttribute("mod see enemy health", 0) == 0) return
			local isPenetration = crossbow.GetAttribute("projectile penetration", 0)
			
			if(IsPlayerABot(params.const_entity)) {
				local headOrigin = isPenetration == 1 ? bot.GetAttachmentOrigin(bot.LookupAttachment("head")) : bot.GetBoneOrigin(bot.LookupBone("bip_head"))
				//non giant range < 6, giant range < 11
				//pene 9, 14
				local distToCheck = bot.IsMiniBoss() ? 11 : 7;
				distToCheck = isPenetration ? distToCheck + 3 : distToCheck

				if((params.damage_position - headOrigin).Length() < distToCheck) {
					params.damage_type = params.damage_type | DMG_ACID //crit
					params.damage_stats = TF_DMG_CUSTOM_HEADSHOT
					if(!syringe.IsValid()) return
					syringe.ValidateScriptScope()
					syringe.GetScriptScope().isAllowedToTeleport <- false 
				}
				if(isPenetration) {
					syringe.GetScriptScope().isAllowedToTeleport <- false 
				}
			}
		}
		
		OnGameEvent_player_death = function(params) {
			local player = GetPlayerFromUserID(params.userid)
			if(IsPlayerABot(player)) return
			if(params.weapon_logclassname != "deflect_arrow") return
			local objRes = Entities.FindByClassname(null, "tf_objective_resource")
			local wave = NetProps.GetPropInt(objRes, "m_nMannVsMachineWaveCount")
			if(wave % 2 == 0 || wave == 7) return //only kill reanim on regular waves

			EntFireByHandle(player, "runscriptcode", "arrowdeath.killReanim()", -1, player, null)
		}

		killReanim = function() {
			local reanim = null
			while(reanim = Entities.FindByClassname(reanim, "entity_revive_marker")) {
				local owner = NetProps.GetPropEntity(reanim, "m_hOwner")
				if(owner != activator) return

				local particle1 = SpawnEntityFromTable("info_particle_system", {
					effect_name = "utaunt_hands_teamcolor_blue"
					start_active = true
					origin = reanim.GetOrigin()
				})
				local particle2 = SpawnEntityFromTable("info_particle_system", {
					effect_name = "utaunt_tarotcard_blue_glow"
					start_active = true
					origin = reanim.GetOrigin()
				})

				EntFireByHandle(particle1, "Kill", null, 1, null, null)
				EntFireByHandle(particle2, "Kill", null, 1, null, null)
				EntFireByHandle(reanim, "AddOutput", "renderfx 6", -1, null, null)
				EntFireByHandle(reanim, "Kill", null, 1, null, null)
				break
			}
		}
	}
	__CollectGameEventCallbacks(arrowdeath)
}

function crossbowThink() {
	if(NetProps.GetPropInt(self, "m_lifeState") != 0 || self.InCond(TF_COND_HALLOWEEN_GHOST_MODE)) {
		counter = 0
		EntFireByHandle(viewmodel, "DispatchEffect", "ParticleEffectStop", -1, null, null)
		return
	}
	if((Time() - NetProps.GetPropFloat(crossbow, "m_flNextPrimaryAttack")) > INTERVAL) return //if fired in the last second
	
	local arrow = null;
	while(arrow = Entities.FindByClassnameWithin(arrow, "tf_projectile_healing_bolt", self.GetOrigin(), 1200)) {
		if(arrow.GetOwner() == self && arrow.GetScriptThinkFunc() == "") {
			arrow.ValidateScriptScope()
			IncludeScript("arrowthinks.nut", arrow.GetScriptScope())
			if(counter < 6) {
				AddThinkToEnt(arrow, "findTargetThink")
				counter++
				if(counter == 6) {
					if(crossbow.GetAttribute("projectile penetration", 0) != 0) {
						hasPenetration = true
					}
					dmgBonus = crossbow.GetAttribute("damage bonus", 0) + 0.5
					//55 at base

					EntFireByHandle(crossbowParticle, "StartTouch", "!activator", -1, viewmodel, viewmodel)
				}
			}
			else {	
				if(!hasFiredReplacement) {
					local traceTable = {
						start = self.Weapon_ShootPosition()
						end = self.Weapon_ShootPosition() + self.EyeAngles().Forward() * SELFHITDISTANCECHECK
						mask = MASK_SHOT
						ignore = self
					}
					TraceLineEx(traceTable)
					
					if(traceTable.hit) { //frick you
						NetProps.SetPropInt(arrow, "m_iDeflected", 1)
						self.TakeDamageEx(arrow, self, crossbow, Vector(), self.GetCenter(), 30 * (1 + dmgBonus),
							DMG_BULLET)
						arrow.Kill()
						
						EntFireByHandle(viewmodel, "DispatchEffect", "ParticleEffectStop", -1, null, null)
						counter = 0
						
						return;
					}
				
					NetProps.SetPropInt(secondaryxbow, "m_AttributeManager.m_Item.m_iItemDefinitionIndex", itemDefIndex)
					secondaryxbow.AddAttribute("damage bonus", dmgBonus, -1)

					local ammo = NetProps.GetPropIntArray(self, "m_iAmmo", 1)
					local charge = NetProps.GetPropFloat(self, "m_Shared.m_flItemChargeMeter")

					NetProps.SetPropIntArray(self, "m_iAmmo", 99, 1)
					NetProps.SetPropFloat(self, "m_Shared.m_flItemChargeMeter", 100.0)
					NetProps.SetPropBool(self, "m_bLagCompensation", false)
					NetProps.SetPropFloat(secondaryxbow, "m_flNextPrimaryAttack", 0)
					NetProps.SetPropEntity(secondaryxbow, "m_hOwner", self)

					secondaryxbow.PrimaryAttack()

					NetProps.SetPropBool(self, "m_bLagCompensation", true)
					NetProps.SetPropIntArray(self, "m_iAmmo", ammo, 1)
					NetProps.SetPropFloat(self, "m_Shared.m_flItemChargeMeter", charge)
					secondaryxbow.RemoveAttribute("damage bonus")

					hasFiredReplacement = true
					arrow.Kill()
				}
				else {
					AddThinkToEnt(arrow, "hitSelf")
					hasFiredReplacement = false
					counter = 0
				}

				EntFireByHandle(viewmodel, "DispatchEffect", "ParticleEffectStop", -1, null, null)
			}
		}
	}
}

function purchaseCrossbow() {
	for(local i = 0; i < NetProps.GetPropArraySize(self, "m_hMyWeapons"); i++) {
		local weapon = NetProps.GetPropEntityArray(self, "m_hMyWeapons", i);
		if(weapon == null) continue;

		if(weapon.GetClassname() == "tf_weapon_crossbow") {
			crossbow = weapon;
			break
		}
	}
	itemDefIndex = NetProps.GetPropInt(crossbow, "m_AttributeManager.m_Item.m_iItemDefinitionIndex")

	//AddThinkToEnt(self, "crossbowThink")
	
	local level = crossbow.GetAttribute("mod see enemy health", 0)
	if(level > 0) {
		crossbow.AddAttribute("sniper no headshots", 0, -1)
		thinkTable.crossbowThink <- crossbowThink
	}
	else {
		refundCrossbow()
	}
}

function refundCrossbow() {
	if("crossbowThink" in thinkTable) {
		EntFireByHandle(viewmodel, "DispatchEffect", "ParticleEffectStop", -1, null, null)
		delete thinkTable.crossbowThink
	}
}